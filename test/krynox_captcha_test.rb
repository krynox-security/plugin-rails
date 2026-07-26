# frozen_string_literal: true

# Integration tests for the rails-free layers of krynox-captcha-rails:
# Krynox::Captcha.verify (real Net::HTTP against a local mock data plane),
# configuration, and ControllerHelpers mixed into a fake controller.
# Stdlib only — no rails gem required (view_helpers/railtie are not covered here).

require "minitest/autorun"
require "socket"
require "json"

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "krynox/captcha"

# Minimal HTTP/1.1 mock of the Krynox data plane on a real TCP socket.
# Responses are scripted per-request; every received request body is recorded.
class MockPlane
  attr_reader :requests

  def initialize
    @requests = []
    @script = []
    @mutex = Mutex.new
    @server = TCPServer.new("127.0.0.1", 0)
    @port = @server.addr[1]
    @accept_thread = Thread.new do
      loop do
        sock = @server.accept
        Thread.new(sock) { |s| handle(s) }
      rescue IOError, Errno::EBADF
        break
      end
    end
  end

  def url
    "http://127.0.0.1:#{@port}"
  end

  # Queue one scripted response. body is a String written verbatim.
  # hang: seconds to sit on the open socket without responding (timeout tests).
  def enqueue(status, body, hang: nil)
    @mutex.synchronize { @script << { status: status, body: body, hang: hang } }
  end

  def stop
    @server.close
  rescue IOError
    nil
  end

  private

  def handle(sock)
    request_line = sock.gets
    headers = {}
    while (line = sock.gets) && line != "\r\n"
      key, value = line.split(":", 2)
      headers[key.downcase] = value.to_s.strip
    end
    raw = sock.read(headers["content-length"].to_i)
    step = @mutex.synchronize { @script.shift } || { status: 200, body: JSON.generate("success" => true) }
    @mutex.synchronize do
      @requests << {
        path: request_line.split[1],
        content_type: headers["content-type"],
        body: begin
          JSON.parse(raw)
        rescue JSON::ParserError
          raw
        end
      }
    end
    if step[:hang]
      sleep step[:hang]
    else
      body = step[:body]
      sock.write(
        "HTTP/1.1 #{step[:status]} Whatever\r\n" \
        "Content-Type: application/json\r\n" \
        "Content-Length: #{body.bytesize}\r\n" \
        "Connection: close\r\n\r\n#{body}"
      )
    end
    sock.close
  rescue StandardError
    sock.close rescue nil
  end
end

# Fake controller exercising exactly what ControllerHelpers reads:
# params, request.remote_ip, respond_to/format blocks, redirect_back, render.
class FakeController
  include Krynox::Captcha::ControllerHelpers

  FakeRequest = Struct.new(:remote_ip)

  class FormatCollector
    def initialize
      @blocks = {}
    end

    def html(&block)
      @blocks[:html] = block
    end

    def json(&block)
      @blocks[:json] = block
    end

    def run(format)
      @blocks[format]&.call
    end
  end

  attr_reader :params, :request, :redirected_to, :rendered

  def initialize(params:, remote_ip: "203.0.113.9", format: :html)
    @params = params
    @request = FakeRequest.new(remote_ip)
    @format = format
  end

  def respond_to
    collector = FormatCollector.new
    yield collector
    collector.run(@format)
  end

  def redirect_back(fallback_location:, alert: nil)
    @redirected_to = { fallback_location: fallback_location, alert: alert }
  end

  def render(json:, status:)
    @rendered = { json: json, status: status }
  end
end

class KrynoxCaptchaTest < Minitest::Test
  SUCCESS_BODY = JSON.generate(
    "success" => true,
    "score" => 0.92,
    "risk" => "low",
    "hostname" => "example.com",
    "challenge_ts" => "2026-07-27T00:00:00Z",
    "error-codes" => [],
    "reasons" => ["pow-valid"],
    "agent" => { "verified" => true, "name" => "example-agent", "allowlisted" => false },
    "human" => { "attested" => true, "method" => "pat", "issuer" => "apple" }
  )

  def setup
    @plane = MockPlane.new
    Krynox::Captcha.instance_variable_set(:@config, nil)
    Krynox::Captcha.configure do |c|
      c.site_key = "kcpt_test"
      c.secret_key = "kcps_test"
      c.api_host = @plane.url
      c.timeout = 2
      c.retries = 2
    end
  end

  def teardown
    @plane.stop
    Krynox::Captcha.instance_variable_set(:@config, nil)
  end

  def test_verify_happy_path_full_result_and_exact_body_keys
    @plane.enqueue(200, SUCCESS_BODY)

    result = Krynox::Captcha.verify("tok_solved", remoteip: "198.51.100.7", honeypot: "bot-fill")

    assert_equal true, result[:success]
    assert_in_delta 0.92, result[:score]
    assert_equal "low", result[:risk]
    assert_equal "example.com", result[:hostname]
    assert_equal "2026-07-27T00:00:00Z", result[:challenge_ts]
    assert_equal [], result[:error_codes]
    assert_equal ["pow-valid"], result[:reasons]
    assert_equal({ verified: true, name: "example-agent", allowlisted: false }, result[:agent])
    assert_equal({ attested: true, method: "pat", issuer: "apple" }, result[:human])

    assert_equal 1, @plane.requests.length
    req = @plane.requests.first
    assert_equal "/siteverify", req[:path]
    assert_equal "application/json", req[:content_type]
    assert_equal %w[secret response remoteip honeypot idempotency_key], req[:body].keys
    assert_equal "kcps_test", req[:body]["secret"]
    assert_equal "tok_solved", req[:body]["response"]
    assert_equal "198.51.100.7", req[:body]["remoteip"]
    assert_equal "bot-fill", req[:body]["honeypot"]
    # retries > 0 → an idempotency key is always sent
    assert_match(/\A\h{32}\z/, req[:body]["idempotency_key"])
  end

  def test_verify_retries_500_then_succeeds_with_same_idempotency_key
    @plane.enqueue(500, "boom")
    @plane.enqueue(200, SUCCESS_BODY)

    result = Krynox::Captcha.verify("tok_solved")

    assert_equal true, result[:success]
    assert_equal 2, @plane.requests.length
    keys = @plane.requests.map { |r| r[:body]["idempotency_key"] }
    refute_nil keys.first
    assert_equal keys.first, keys.last
  end

  def test_verify_retries_429_then_succeeds
    @plane.enqueue(429, "slow down")
    @plane.enqueue(200, SUCCESS_BODY)

    result = Krynox::Captcha.verify("tok_solved")

    assert_equal true, result[:success]
    assert_equal 2, @plane.requests.length
    keys = @plane.requests.map { |r| r[:body]["idempotency_key"] }
    refute_nil keys.first
    assert_equal keys.first, keys.last
  end

  def test_verify_exhausted_retries_returns_request_failed
    # Non-JSON 500 bodies: the final attempt JSON.parses the body, so a JSON
    # error body would be returned as data — non-JSON forces the nil path.
    3.times { @plane.enqueue(500, "boom") }

    result = Krynox::Captcha.verify("tok_solved")

    assert_equal false, result[:success]
    assert_equal ["request-failed"], result[:error_codes]
    assert_equal 3, @plane.requests.length
  end

  def test_verify_timeout_returns_request_failed
    Krynox::Captcha.config.retries = 0
    Krynox::Captcha.config.timeout = 0.3
    @plane.enqueue(200, SUCCESS_BODY, hang: 3)

    started = Time.now
    result = Krynox::Captcha.verify("tok_solved")

    assert_equal false, result[:success]
    assert_equal ["request-failed"], result[:error_codes]
    assert_operator Time.now - started, :<, 2.5
    assert_equal 1, @plane.requests.length
  end

  def test_verify_missing_response_short_circuits_without_http
    ["", nil].each do |empty|
      result = Krynox::Captcha.verify(empty)
      assert_equal false, result[:success]
      assert_equal ["missing-input-response"], result[:error_codes]
    end
    assert_equal 0, @plane.requests.length
  end

  def test_controller_verified_true_and_forwards_params_remote_ip_honeypot
    @plane.enqueue(200, SUCCESS_BODY)
    controller = FakeController.new(
      params: { "krynox-captcha" => "tok_solved", "krynox-hp" => "trap-value" },
      remote_ip: "192.0.2.44"
    )

    assert_equal true, controller.krynox_captcha_verified?

    req = @plane.requests.first
    assert_equal "tok_solved", req[:body]["response"]
    assert_equal "192.0.2.44", req[:body]["remoteip"]
    assert_equal "trap-value", req[:body]["honeypot"]
    assert_equal "kcps_test", req[:body]["secret"]
  end

  def test_controller_verified_false_on_failed_verification
    @plane.enqueue(200, JSON.generate("success" => false, "error-codes" => ["invalid-input-response"]))
    controller = FakeController.new(params: { "krynox-captcha" => "tok_bad" })

    assert_equal false, controller.krynox_captcha_verified?
  end

  def test_require_krynox_captcha_passes_through_on_success
    @plane.enqueue(200, SUCCESS_BODY)
    controller = FakeController.new(params: { "krynox-captcha" => "tok_solved" })

    controller.require_krynox_captcha

    assert_nil controller.redirected_to
    assert_nil controller.rendered
  end

  def test_require_krynox_captcha_redirects_back_for_html_on_failure
    @plane.enqueue(200, JSON.generate("success" => false, "error-codes" => ["invalid-input-response"]))
    controller = FakeController.new(params: { "krynox-captcha" => "tok_bad" }, format: :html)

    controller.require_krynox_captcha

    assert_equal({ fallback_location: "/", alert: "CAPTCHA verification failed." }, controller.redirected_to)
    assert_nil controller.rendered
  end

  def test_require_krynox_captcha_renders_403_json_on_failure
    @plane.enqueue(200, JSON.generate("success" => false, "error-codes" => ["invalid-input-response"]))
    controller = FakeController.new(params: { "krynox-captcha" => "tok_bad" }, format: :json)

    controller.require_krynox_captcha

    assert_equal({ json: { error: "captcha_failed" }, status: :forbidden }, controller.rendered)
    assert_nil controller.redirected_to
  end
end

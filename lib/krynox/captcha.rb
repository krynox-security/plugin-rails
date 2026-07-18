# frozen_string_literal: true

require "cgi"
require "erb"
require "json"
require "net/http"
require "securerandom"
require "uri"

require "krynox/captcha/version"

# Krynox Captcha for Rails — privacy-first, proof-of-work CAPTCHA.
#
#   # config/initializers/krynox.rb
#   Krynox::Captcha.configure do |c|
#     c.site_key   = ENV["KRYNOX_SITE_KEY"]
#     c.secret_key = ENV["KRYNOX_SECRET_KEY"]
#   end
module Krynox
  module Captcha
    DEFAULT_API_HOST = "https://api.krynox.net"
    DEFAULT_CDN_HOST = "https://cdn.krynox.net"

    # Runtime configuration (defaults from ENV).
    class Config
      attr_accessor :site_key, :secret_key, :api_host, :cdn_host, :timeout, :retries

      def initialize
        @site_key   = ENV["KRYNOX_SITE_KEY"]
        @secret_key = ENV["KRYNOX_SECRET_KEY"]
        @api_host   = ENV.fetch("KRYNOX_API_HOST", DEFAULT_API_HOST)
        @cdn_host   = ENV.fetch("KRYNOX_CDN_HOST", DEFAULT_CDN_HOST)
        @timeout    = 5
        @retries    = 2
      end
    end

    class << self
      def config
        @config ||= Config.new
      end

      def configure
        yield config if block_given?
        config
      end

      # Verify a solved token. Returns a Hash with :success, :score, :risk, :hostname,
      # :challenge_ts, :error_codes, :reasons, :agent, :human. :agent/:human are nested Hashes
      # (or nil) with the verified AI-agent / attested-human identity when forwarded.
      def verify(response, remoteip: nil)
        return fail_result(["missing-input-response"]) if response.nil? || response.to_s.empty?

        # A token is single-use, so a retried verify carries an idempotency key — the server returns
        # the first outcome instead of failing the now-consumed token.
        key = config.retries.positive? ? SecureRandom.hex(16) : nil
        data = post(
          "#{config.api_host.chomp('/')}/siteverify",
          secret: config.secret_key, response: response, remoteip: remoteip, idempotency_key: key
        )
        return fail_result(["request-failed"]) if data.nil?

        agent = data["agent"]
        human = data["human"]
        {
          success: data["success"] == true,
          score: data["score"],
          risk: data["risk"],
          hostname: data["hostname"],
          challenge_ts: data["challenge_ts"],
          error_codes: Array(data["error-codes"]),
          reasons: Array(data["reasons"]),
          agent: agent.is_a?(Hash) ? { verified: agent["verified"] == true, name: agent["name"], allowlisted: agent["allowlisted"] == true } : nil,
          human: human.is_a?(Hash) ? { attested: human["attested"] == true, method: human["method"], issuer: human["issuer"] } : nil
        }
      end

      private

      def fail_result(codes)
        { success: false, score: nil, risk: nil, hostname: nil, challenge_ts: nil,
          error_codes: codes, reasons: [], agent: nil, human: nil }
      end

      # POST JSON, retrying transient failures (network / 429 / 5xx). Returns a parsed Hash or nil.
      def post(url, body)
        uri = URI.parse(url)
        payload = JSON.generate(body)
        retries = config.retries
        (0..retries).each do |attempt|
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = (uri.scheme == "https")
          http.open_timeout = config.timeout
          http.read_timeout = config.timeout
          req = Net::HTTP::Post.new(uri.request_uri, "content-type" => "application/json")
          req.body = payload
          res = http.request(req)
          code = res.code.to_i
          if (code == 429 || code >= 500) && attempt < retries
            sleep([1.0, 0.1 * (2**attempt)].min)
            next
          end
          return JSON.parse(res.body)
        rescue StandardError
          sleep([1.0, 0.1 * (2**attempt)].min) if attempt < retries
          next if attempt < retries

          return nil
        end
        nil
      end
    end
  end
end

require "krynox/captcha/view_helpers"
require "krynox/captcha/controller_helpers"
require "krynox/captcha/railtie" if defined?(Rails::Railtie)

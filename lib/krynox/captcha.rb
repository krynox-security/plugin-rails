# frozen_string_literal: true

require "cgi"
require "erb"
require "json"
require "net/http"
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
    DEFAULT_API_HOST = "https://api.krynox.id"
    DEFAULT_CDN_HOST = "https://cdn.krynox.id"

    # Runtime configuration (defaults from ENV).
    class Config
      attr_accessor :site_key, :secret_key, :api_host, :cdn_host, :timeout

      def initialize
        @site_key   = ENV["KRYNOX_SITE_KEY"]
        @secret_key = ENV["KRYNOX_SECRET_KEY"]
        @api_host   = ENV.fetch("KRYNOX_API_HOST", DEFAULT_API_HOST)
        @cdn_host   = ENV.fetch("KRYNOX_CDN_HOST", DEFAULT_CDN_HOST)
        @timeout    = 5
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

      # Verify a solved token. Returns a Hash with :success, :score, :risk, :error_codes.
      def verify(response, remoteip: nil)
        return fail_result(["missing-input-response"]) if response.nil? || response.to_s.empty?

        data = post(
          "#{config.api_host.chomp('/')}/siteverify",
          secret: config.secret_key, response: response, remoteip: remoteip
        )
        return fail_result(["request-failed"]) if data.nil?

        {
          success: data["success"] == true,
          score: data["score"],
          risk: data["risk"],
          hostname: data["hostname"],
          challenge_ts: data["challenge_ts"],
          error_codes: Array(data["error-codes"])
        }
      end

      private

      def fail_result(codes)
        { success: false, score: nil, risk: nil, hostname: nil, challenge_ts: nil, error_codes: codes }
      end

      def post(url, body)
        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == "https")
        http.open_timeout = config.timeout
        http.read_timeout = config.timeout
        req = Net::HTTP::Post.new(uri.request_uri, "content-type" => "application/json")
        req.body = JSON.generate(body)
        JSON.parse(http.request(req).body)
      rescue StandardError
        nil
      end
    end
  end
end

require "krynox/captcha/view_helpers"
require "krynox/captcha/controller_helpers"
require "krynox/captcha/railtie" if defined?(Rails::Railtie)

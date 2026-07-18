# frozen_string_literal: true

require_relative "lib/krynox/captcha/version"

Gem::Specification.new do |spec|
  spec.name        = "krynox-captcha-rails"
  spec.version     = Krynox::Captcha::VERSION
  spec.authors     = ["Krynox"]
  spec.email       = ["support@krynox.net"]

  spec.summary     = "Krynox Captcha for Rails — view helper + controller verification."
  spec.description = "Privacy-first, proof-of-work CAPTCHA for Ruby on Rails: a view helper to render the widget and a controller helper to verify it server-side."
  spec.homepage    = "https://krynox.net"
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 2.7"

  spec.metadata["source_code_uri"]   = "https://github.com/krynox-security/plugin-rails"
  spec.metadata["documentation_uri"] = "https://docs.krynox.net"

  spec.files         = Dir["lib/**/*.rb", "README.md", "LICENSE"]
  spec.require_paths = ["lib"]
end

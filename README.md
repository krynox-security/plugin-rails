# Krynox Captcha for Rails

Privacy-first, proof-of-work CAPTCHA for Ruby on Rails — a view helper to render the
widget and a controller helper to verify it. No cookies, no puzzles.

## Install

```ruby
# Gemfile
gem "krynox-captcha-rails"
```

```bash
bundle install
```

Configure (defaults read from `ENV`):

```ruby
# config/initializers/krynox.rb
Krynox::Captcha.configure do |c|
  c.site_key   = ENV["KRYNOX_SITE_KEY"]
  c.secret_key = ENV["KRYNOX_SECRET_KEY"]
  # c.api_host = "https://api.krynox.net"  # self-hosting
  # c.cdn_host = "https://cdn.krynox.net"
end
```

## Render the widget

```erb
<%= form_with url: signup_path do |f| %>
  <%= f.email_field :email %>
  <%= krynox_captcha_tag %>
  <%= f.submit "Create account" %>
<% end %>
```

## Verify the submission

```ruby
class SignupsController < ApplicationController
  before_action :require_krynox_captcha, only: :create

  def create
    # reached only when the captcha verified
  end
end
```

Or check it yourself:

```ruby
if krynox_captcha_verified?       # controller helper
  # ...
end

result = Krynox::Captcha.verify(params["krynox-captcha"], remoteip: request.remote_ip)
# result[:success], result[:risk] => "low" | "medium" | "high"
# result[:reasons] => ["tor-exit", ...]; result[:agent]; result[:human]
```

`verify` returns the full contract — `:success`, `:score`, `:risk`, `:hostname`, `:challenge_ts`,
`:error_codes`, `:reasons`, `:agent` (`{verified:, name:, allowlisted:}` or `nil`), `:human`
(`{attested:, method:, issuer:}` or `nil`). Transient failures (network / 429 / 5xx) are retried
automatically (`config.retries`, default 2) with a per-verify idempotency key.

## Honeypot

Enable **Honeypot** for the site in the Krynox dashboard and the widget injects an invisible decoy
field (`krynox-hp`) that only bots fill in. The `require_krynox_captcha` / `krynox_captcha_verified?`
helpers forward it to `/siteverify` as `honeypot` automatically — no code change needed (a manual
`Krynox::Captcha.verify(token, honeypot: params["krynox-hp"])` call works too). The data plane then
floors the score (report mode) or rejects with `honeypot-tripped` (enforce mode). See the
[Honeypot docs](https://docs.krynox.net/server-side/honeypot/).

## License

MIT. Built for [Krynox Captcha](https://krynox.net) · docs: <https://krynox.net/docs>

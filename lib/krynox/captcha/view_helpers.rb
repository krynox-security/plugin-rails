# frozen_string_literal: true

module Krynox
  module Captcha
    # Auto-mixed into ActionView (see Railtie). Renders the widget in a view:
    #
    #   <%= krynox_captcha_tag %>
    module ViewHelpers
      def krynox_captcha_tag(sitekey: nil)
        cfg = Krynox::Captcha.config
        key = sitekey || cfg.site_key
        api = cfg.api_host.chomp("/")
        cdn = cfg.cdn_host.chomp("/")
        challenge = "#{api}/challenge?sitekey=#{CGI.escape(key.to_s)}"

        html = +""
        html << %(<script async defer src="#{cdn}/widget/krynox-captcha.js" type="module"></script>)
        html << %(<krynox-captcha challenge="#{ERB::Util.html_escape(challenge)}"></krynox-captcha>)
        html.respond_to?(:html_safe) ? html.html_safe : html
      end
    end
  end
end

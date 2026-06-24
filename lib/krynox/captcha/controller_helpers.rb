# frozen_string_literal: true

module Krynox
  module Captcha
    # Auto-mixed into ActionController (see Railtie). Use in a controller:
    #
    #   before_action :require_krynox_captcha, only: :create
    module ControllerHelpers
      # True when the submitted captcha verifies server-side.
      def krynox_captcha_verified?
        Krynox::Captcha.verify(params["krynox-captcha"], remoteip: request.remote_ip)[:success]
      end

      # before_action guard: blocks the request on failure.
      def require_krynox_captcha
        return if krynox_captcha_verified?

        respond_to do |format|
          format.html { redirect_back fallback_location: "/", alert: "CAPTCHA verification failed." }
          format.json { render(json: { error: "captcha_failed" }, status: :forbidden) }
        end
      end
    end
  end
end

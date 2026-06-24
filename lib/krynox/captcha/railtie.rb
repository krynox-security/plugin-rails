# frozen_string_literal: true

require "rails/railtie"

module Krynox
  module Captcha
    # Wires the view + controller helpers into Rails automatically.
    class Railtie < ::Rails::Railtie
      initializer "krynox_captcha.helpers" do
        ActiveSupport.on_load(:action_view) do
          include Krynox::Captcha::ViewHelpers
        end
        ActiveSupport.on_load(:action_controller) do
          include Krynox::Captcha::ControllerHelpers
        end
      end
    end
  end
end

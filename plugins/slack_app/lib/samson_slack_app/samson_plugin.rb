# frozen_string_literal: true
module SamsonSlackApp
  class SamsonPlugin < Rails::Engine
  end
end

callback = ->(deploy, _) { SamsonSlackApp::SlackMessage.new(deploy).deliver }

Samson::Hooks.callback :before_deploy, &callback
Samson::Hooks.callback :after_deploy, &callback

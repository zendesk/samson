# frozen_string_literal: true
module SamsonSlackApp
  class Engine < Rails::Engine
  end
end

callback = -> (deploy, _buddy) { SlackMessage.new(deploy).deliver }

Samson::Hooks.callback :before_deploy, &callback
Samson::Hooks.callback :after_deploy, &callback

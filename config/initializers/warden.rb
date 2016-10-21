# frozen_string_literal: true
require 'warden'

Warden::Manager.serialize_into_session(&:id)

Warden::Manager.serialize_from_session do |id|
  User.find(id)
end

require 'warden/strategies/basic_strategy'
require "warden/strategies/doorkeeper_strategy"

Rails.application.config.middleware.insert_after(ActionDispatch::Flash, Warden::Manager) do |manager|
  manager.default_strategies :basic, :doorkeeper
  manager.failure_app = UnauthorizedController
  manager.intercept_401 = false # doorkeeper sends direct 401s
end

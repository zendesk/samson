# frozen_string_literal: true
# tested via test/integration/authentication_test.rb
require 'warden'

Warden::Manager.serialize_into_session(&:id)

Warden::Manager.serialize_from_session do |id|
  timeout = Integer(ENV['SESSION_EXPIRATION'] || 1.month).seconds.ago
  User.where('last_login_at > ?', timeout).find_by_id(id)
end

require 'warden/strategies/basic_strategy'
require "warden/strategies/doorkeeper_strategy"

Rails.application.config.middleware.insert_after(ActionDispatch::Flash, Warden::Manager) do |manager|
  manager.default_strategies :basic, :doorkeeper
  manager.failure_app = UnauthorizedController
  manager.intercept_401 = false # doorkeeper sends direct 401s
end

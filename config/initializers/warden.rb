# frozen_string_literal: true
# tested via test/integration/authentication_test.rb
require 'warden'

Warden::Manager.serialize_into_session(&:id)

# Login users unless their login is too old
Warden::Manager.serialize_from_session do |id|
  timeout = Integer(ENV['SESSION_EXPIRATION'] || 1.month).seconds.ago
  User.where('last_login_at > ?', timeout).find_by_id(id)
end

# Keep track of who currently uses samson
Warden::Manager.after_set_user do |user|
  user.update_column(:last_seen_at, Time.now) unless user.last_seen_at&.> 10.minutes.ago
end

require "warden/strategies/doorkeeper_strategy"

Rails.application.config.middleware.insert_after(ActionDispatch::Flash, Warden::Manager) do |manager|
  manager.default_strategies *manager.strategies._strategies.keys
  manager.failure_app = UnauthorizedController
  manager.intercept_401 = false # doorkeeper sends direct 401s with good content
end

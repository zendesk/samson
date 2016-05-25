require 'warden'

Warden::Manager.serialize_into_session(&:id)

Warden::Manager.serialize_from_session do |id|
  User.find(id)
end

require 'warden/strategies/basic_strategy'
require 'warden/strategies/session_strategy'

Rails.application.config.middleware.insert_after(ActionDispatch::Flash, Warden::Manager) do |manager|
  manager.default_strategies :basic, :session
  manager.failure_app = UnauthorizedController
end

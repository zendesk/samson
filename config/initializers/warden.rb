require 'warden'

Warden::Manager.serialize_into_session do |user|
  user.id
end

Warden::Manager.serialize_from_session do |id|
  User.find_by_id(id)
end

require 'warden/strategies/basic_strategy'
require 'warden/strategies/zendesk_oauth2_strategy'

Rails.application.config.middleware.insert_after(ActionDispatch::Flash, Warden::Manager) do |manager|
  manager.default_strategies :basic, :zendesk_oauth2

  manager.failure_app = Class.new do
    def call(env)
      [401, {}, '']
    end
  end
end

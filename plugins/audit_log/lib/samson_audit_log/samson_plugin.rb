# frozen_string_literal: true
require 'splunk_logger'

module SamsonAuditLog
  class Engine < Rails::Engine
  end

  class Audit
    VALID_METHODS = Set[:info, :warn, :debug, :error]

    def self.log(level, user, action, *args)
      return unless AUDIT_LOG_CLIENT
      raise ArgumentError unless VALID_METHODS.include?(level)

      message = {
        actor: SamsonAuditLog::AuditPresenter.present(user),
        time: Time.now,
        action: action
      }
      args.each_with_index do |arg, i|
        message[arg.class.name.underscore + i.to_s] = SamsonAuditLog::AuditPresenter.present(arg)
      end
      AUDIT_LOG_CLIENT.public_send(level, message)
    end
  end
end

Samson::Hooks.callback :unauthorized_action do |current_user, controller, method|
  SamsonAuditLog::Audit.log(:warn, current_user, 'unauthorized action', controller: controller, method: method)
end

Samson::Hooks.callback :after_deploy do |deploy|
  SamsonAuditLog::Audit.log(:info, nil, 'deploy ended', deploy)
end

Samson::Hooks.callback :before_deploy do |deploy|
  SamsonAuditLog::Audit.log(:info, nil, 'deploy started', deploy)
end

Samson::Hooks.callback :audit_action do |current_user, action_text, *objects|
  SamsonAuditLog::Audit.log(:info, current_user, action_text, *objects)
end

Samson::Hooks.callback :merged_user do |current_user, user, target|
  SamsonAuditLog::Audit.log(:warn, current_user, 'merged user1 into user0', user, target)
end

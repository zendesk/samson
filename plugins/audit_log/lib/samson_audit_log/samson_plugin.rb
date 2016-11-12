# frozen_string_literal: true
require 'splunk_logger'

module SamsonAuditLog
  class Engine < Rails::Engine
  end

  class Audit
    class << self
      VALID_METHODS = [:info, :warn, :debug, :error]

      def plugin_enabled?
        ENV['AUDIT_PLUGIN'] == '1' && !ENV['SPLUNK_TOKEN'].nil? && !ENV['SPLUNK_URL'].nil?
      end

      def log(level, user, action, *args)
        raise ArgumentError unless VALID_METHODS.include?(level)
        return unless plugin_enabled?

        message = {}
        message[:actor] = SamsonAuditLog::AuditPresenter.present(user)
        message[:time] = Time.now
        message[:action] = action
        args.each_with_index do |arg, i|
          message['subject' + i.to_s] = SamsonAuditLog::AuditPresenter.present(arg)
        end
        client.send(level, message)
      end

      private

      def client
        ssl_verify = ENV['SPLUNK_DISABLE_VERIFY_SSL'] != "1"
        SplunkLogger::Client.new({token: ENV['SPLUNK_TOKEN'], url: ENV['SPLUNK_URL'], verify_ssl: ssl_verify});
      end
    end
  end
end

Samson::Hooks.callback :unauthorized_action do |current_user, controller, method|
  SamsonAuditLog::Audit.log(:warn, current_user, 'unauthorized action', {controller: controller, method: method})
end

Samson::Hooks.callback :after_deploy do |deploy|
  SamsonAuditLog::Audit.log(:info, nil, 'deploy ended', deploy)
end

Samson::Hooks.callback :before_deploy do |deploy|
  SamsonAuditLog::Audit.log(:info, nil, 'deploy started', deploy)
end

Samson::Hooks.callback :audit_action do |current_user, action_text, object|
  SamsonAuditLog::Audit.log(:info, current_user, action_text, object)
end

Samson::Hooks.callback :merged_user do |current_user, user, target|
  SamsonAuditLog::Audit.log(:warn, current_user, 'merged user subject1 into subject0', user, target)
end

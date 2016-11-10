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

      def client
        ssl_verify = ENV['SPLUNK_DISABLE_VERIFY_SSL'] != "1"
        SplunkLogger::Client.new({token: ENV['SPLUNK_TOKEN'], url: ENV['SPLUNK_URL'], verify_ssl: ssl_verify});
      end

      def log(level, user, action, *args)
        throw ArgumentError unless VALID_METHODS.include?(level)
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
    end
  end
end

Samson::Hooks.callback :unauthorized_action do |current_user, controller, method|
  SamsonAuditLog::Audit.log(:warn, current_user, 'unauthorized action', {controller: controller, method: method})
end

Samson::Hooks.callback :after_deploy do |deploy, buddy|
  SamsonAuditLog::Audit.log(:info, {}, 'deploy completed', deploy, buddy)
end

Samson::Hooks.callback :controller_action do |current_user, action_text, object|
  SamsonAuditLog::Audit.log(:info, current_user, action_text, object)
end

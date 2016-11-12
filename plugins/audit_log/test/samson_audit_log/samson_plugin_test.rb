# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! unless defined?(Rake) # rake preloads all plugins

describe SamsonAuditLog do
  before do
    @event_sent = stub_request(:post, 'https://foo.bar/services/collector/event').to_return(status: 200)
  end

  with_env(SPLUNK_URL: 'https://foo.bar', SPLUNK_TOKEN: 'sometoken', AUDIT_PLUGIN: '1')

  describe 'SamsonAuditLog::Audit' do
    describe '.plugin_enabled?' do
      it 'is enabled' do
        assert SamsonAuditLog::Audit.plugin_enabled?
      end

      it 'is not enabled without plugin 1' do
        ENV.delete('AUDIT_PLUGIN')
        refute SamsonAuditLog::Audit.plugin_enabled?
      end

      it 'is not enabled without token' do
        ENV.delete('SPLUNK_TOKEN')
        refute SamsonAuditLog::Audit.plugin_enabled?
      end

      it 'is not enabled without url' do
        ENV.delete('SPLUNK_URL')
        refute SamsonAuditLog::Audit.plugin_enabled?
      end
    end

    describe '.log' do
      it 'raises ArgumentError with invalid status' do
        assert_raises ArgumentError do
          SamsonAuditLog::Audit.log(:invalid, {}, '', {})
        end
      end

      it 'does not send with plugin disabled' do
        ENV.delete('AUDIT_PLUGIN')
        SamsonAuditLog::Audit.log(:info, {}, '', {})
        assert_not_requested @event_sent
      end

      it 'sends log with no *args' do
        SamsonAuditLog::Audit.log(:info, {}, '')
        assert_requested @event_sent
      end

      it 'sends log with 1 *args' do
        SamsonAuditLog::Audit.log(:info, {}, '', {})
        assert_requested @event_sent
      end

      it 'sends log with many *args' do
        SamsonAuditLog::Audit.log(:info, {}, '', {}, {})
        assert_requested @event_sent
      end
    end
  end

  describe 'callbacks' do
    let(:user) { User.first }
    let(:deploy) { Deploy.first }

    it 'successfully fires unauthorized_action' do
      SamsonAuditLog::Audit.expects(:log).
        with(:warn, user, 'unauthorized action', controller: 'user', method: 'delete').once
      Samson::Hooks.fire(:unauthorized_action, user, 'user', 'delete')
    end

    it 'successfully fires after_deploy' do
      SamsonAuditLog::Audit.expects(:log).with(:info, nil, 'deploy ended', deploy).once
      Samson::Hooks.fire(:after_deploy, deploy, user)
    end

    it 'successfully fires before_deploy' do
      SamsonAuditLog::Audit.expects(:log).with(:info, nil, 'deploy started', deploy).once
      Samson::Hooks.fire(:before_deploy, deploy, user)
    end

    it 'successfully fires audit_action' do
      SamsonAuditLog::Audit.expects(:log).with(:info, user, 'created deploy', deploy).once
      Samson::Hooks.fire(:audit_action, user, 'created deploy', deploy)
    end

    it 'successfully fires merged_user' do
      target = User.last
      SamsonAuditLog::Audit.expects(:log).with(:warn, user, 'merged user subject1 into subject0', user, target).once
      Samson::Hooks.fire(:merged_user, user, user, target)
    end
  end
end

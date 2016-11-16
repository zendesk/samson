# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! unless defined?(Rake) # rake preloads all plugins

describe SamsonAuditLog do
  before do
    @event_sent = stub_request(:post, 'https://foo.bar/services/collector/event').to_return(status: 200)
  end

  describe 'SamsonAuditLog::Audit' do
    describe '.log' do
      before { undo_default_audit_stubs }

      it 'raises ArgumentError with invalid method' do
        assert_raises ArgumentError do
          SamsonAuditLog::Audit.log(:invalid, {}, '', {})
        end
      end

      it 'does not reach valid methods check without client' do
        SamsonAuditLog::Audit::VALID_METHODS.expects(:include?).never
        silence_warnings do # disable ruby warnings about changing a defined constant
          begin
            @old = AUDIT_LOG_CLIENT
            AUDIT_LOG_CLIENT = nil
            SamsonAuditLog::Audit.log(:info, {}, '', {})
          ensure
            AUDIT_LOG_CLIENT = @old # make sure we reset the constant to previous state
          end
        end
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

    it 'successfully fires audit_action with 0 subject objects' do
      SamsonAuditLog::Audit.expects(:log).with(:info, user, 'created deploy').once
      Samson::Hooks.fire(:audit_action, user, 'created deploy')
    end

    it 'successfully fires audit_action with 1 subject object' do
      SamsonAuditLog::Audit.expects(:log).with(:info, user, 'created deploy', deploy).once
      Samson::Hooks.fire(:audit_action, user, 'created deploy', deploy)
    end

    it 'successfully fires audit_action with many subject objects' do
      SamsonAuditLog::Audit.expects(:log).with(:info, user, 'created deploy', :test, 'test', deploy).once
      Samson::Hooks.fire(:audit_action, user, 'created deploy', :test, 'test', deploy)
    end

    it 'successfully fires merged_user' do
      target = User.last
      SamsonAuditLog::Audit.expects(:log).with(:warn, user, 'merged user1 into user0', user, target).once
      Samson::Hooks.fire(:merged_user, user, user, target)
    end
  end
end

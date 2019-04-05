# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SamsonDatadog do
  let(:deploy) { deploys(:succeeded_test) }
  let(:stage) { deploy.stage }

  describe '.send_notification' do
    it 'sends notification' do
      stage.stubs(:send_datadog_notifications?).returns(true)
      dd_notification_mock = mock
      dd_notification_mock.expects(:deliver).with(additional_tags: ['started'])
      DatadogNotification.expects(:new).with(deploy).returns(dd_notification_mock)

      SamsonDatadog.send_notification(deploy, additional_tags: ['started'])
    end

    it 'does not send notifications when disabled' do
      DatadogNotification.expects(:new).never
      Samson::Hooks.fire(:after_deploy, deploy, stub(output: nil))
    end
  end

  describe :stage_permitted_params do
    it 'lists extra keys' do
      Samson::Hooks.fire(:stage_permitted_params).must_include [:datadog_tags, :datadog_monitor_ids]
    end
  end

  describe :before_deploy do
    only_callbacks_for_plugin :before_deploy

    it 'sends notification on before hook' do
      SamsonDatadog.expects(:send_notification).with(deploy, additional_tags: ['started'], now: true)
      Samson::Hooks.fire(:before_deploy, deploy, nil)
    end
  end

  describe :after_deploy do
    only_callbacks_for_plugin :after_deploy

    it 'sends notification on after hook' do
      stage.stubs(:send_datadog_notifications?).returns(true)
      SamsonDatadog.expects(:send_notification).with(deploy, additional_tags: ['finished'])
      Samson::Hooks.fire(:after_deploy, deploy, stub(output: nil))
    end
  end
end

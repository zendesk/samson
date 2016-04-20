require_relative '../test_helper'

SingleCov.covered! unless defined?(Rake) # rake preloads all plugins

describe SamsonDatadog do
  include StagePermittedParams

  let(:deploy) { deploys(:succeeded_test) }
  let(:stage) { deploy.stage }

  describe :stage_permitted_params do
    it "lists extra keys" do
      params = stage_permitted_params
      params.must_include :datadog_tags
      params.must_include :datadog_monitor_ids
    end
  end

  describe :after_deploy do
    it "sends notification on after hook" do
      stage.stubs(:send_datadog_notifications?).returns(true)
      DatadogNotification.any_instance.expects(:deliver)
      Samson::Hooks.fire(:after_deploy, deploy, nil)
    end

    it "does not send notifications when disabled" do
      DatadogNotification.any_instance.expects(:deliver).never
      Samson::Hooks.fire(:after_deploy, deploy, nil)
    end
  end
end

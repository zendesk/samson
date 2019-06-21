# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SamsonDatadog do
  let(:deploy) { deploys(:succeeded_test) }
  let(:stage) { deploy.stage }

  describe '.send_notification' do
    it 'sends notification' do
      stage.datadog_tags = "foo"
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

  describe ".store_rollback_monitors" do
    def store(state: "OK")
      stub_request(:get, "https://api.datadoghq.com/api/v1/monitor/123?api_key=dapikey&application_key=dappkey").
        to_return(body: {id: 123, overall_state: state}.to_json)
      SamsonDatadog.store_rollback_monitors(deploy)
      deploy.datadog_monitors_for_rollback
    end

    before do
      deploy.stage.datadog_monitor_queries.build(rollback_on_alert: true, query: "123")
    end

    it "stores good monitors" do
      store.size.must_equal 1
    end

    it "stores nothing when not enabled" do
      deploy.stage.datadog_monitor_queries.clear
      store.size.must_equal 0
    end

    it "stores nothing when not rolling back" do
      deploy.stage.datadog_monitor_queries.first.rollback_on_alert = false
      store.size.must_equal 0
    end

    it "stores nothing when alerting" do
      store(state: "Alert").size.must_equal 0
    end
  end

  describe ".rollback_deploy" do
    def rollback(state: "Alert")
      stub_request(:get, "https://api.datadoghq.com/api/v1/monitor/123?api_key=dapikey&application_key=dappkey").
        to_return(body: {id: 123, overall_state: state, name: "Foo is down"}.to_json)
      SamsonDatadog.rollback_deploy(deploy, stub("Ex", output: out))
    end

    let(:out) { StringIO.new }
    let(:previous_deploy) { deploys(:succeeded_test) }
    let(:rollback_deploy) { deploys(:succeeded_production_test) }
    let(:deploy) do
      project = previous_deploy.project
      job = Job.create!(status: "succeeded", user: previous_deploy.user, project: project, command: "ls")
      Deploy.create!(
        stage: previous_deploy.stage,
        project: project,
        reference: "master",
        job: job
      )
    end

    before do
      deploy.job.commit = "a" * 40
      deploy.datadog_monitors_for_rollback = [DatadogMonitor.new(123, overall_state: "OK")]
    end

    it "rolls back when monitor was triggered" do
      DeployService.any_instance.expects(:deploy).returns(rollback_deploy)
      rollback
      out.string.must_equal <<~LOG
        Alert on datadog monitors:
        Foo is down https://app.datadoghq.com/monitors/123
        Triggered rollback to previous commit v1.0 http://www.test-url.com/projects/foo/deploys/#{rollback_deploy.id}
      LOG
    end

    it "does not roll back when no monitors were captured" do
      DeployService.any_instance.expects(:deploy).never
      deploy.datadog_monitors_for_rollback.clear
      rollback
      out.string.must_equal ""
    end

    it "does not roll back when all monitors are still ok" do
      DeployService.any_instance.expects(:deploy).never
      rollback state: "OK"
      out.string.must_equal "No datadog monitors alerting\n"
    end

    it "does not roll back when there is no previous deploy" do
      DeployService.any_instance.expects(:deploy).never
      previous_deploy.destroy
      rollback
      out.string.must_equal <<~LOG
        Alert on datadog monitors:
        Foo is down https://app.datadoghq.com/monitors/123
        No previous successful commit for rollback found
      LOG
    end

    it "does not roll back when previous deploy was the same commit" do
      DeployService.any_instance.expects(:deploy).never
      previous_deploy.job.update_column(:commit, deploy.commit)
      rollback
      out.string.must_equal <<~LOG
        Alert on datadog monitors:
        Foo is down https://app.datadoghq.com/monitors/123
        No rollback to aaaaaaa, it is the same commit
      LOG
    end

    it "shows errors when rollback failed" do
      rollback_deploy.stubs(persisted?: false)
      rollback_deploy.errors.add :base, "Foo"
      DeployService.any_instance.expects(:deploy).returns(rollback_deploy)
      rollback
      out.string.must_equal <<~LOG
        Alert on datadog monitors:
        Foo is down https://app.datadoghq.com/monitors/123
        Error triggering rollback to previous commit v1.0 Foo
      LOG
    end
  end

  describe :stage_permitted_params do
    it 'lists extra keys' do
      Samson::Hooks.fire(:stage_permitted_params).flatten(1).must_include :datadog_tags
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

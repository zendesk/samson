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

  describe ".store_validation_monitors" do
    def store(state: "OK")
      url = "https://api.datadoghq.com/api/v1/monitor/123?api_key=dapikey&application_key=dappkey&group_states=alert"
      stub_request(:get, url).to_return(body: {id: 123, overall_state: state}.to_json)
      SamsonDatadog.store_validation_monitors(deploy)
      deploy.datadog_monitors_for_validation
    end

    before do
      deploy.stage.datadog_monitor_queries.build(failure_behavior: "fail_deploy", query: "123")
    end

    it "stores good monitors" do
      store.size.must_equal 1
    end

    it "stores nothing when not enabled" do
      deploy.stage.datadog_monitor_queries.clear
      store.size.must_equal 0
    end

    it "stores nothing when not rolling back" do
      deploy.stage.datadog_monitor_queries.first.failure_behavior = ""
      store.size.must_equal 0
    end

    it "stores nothing when alerting" do
      store(state: "Alert").size.must_equal 0
    end
  end

  describe ".validate_deploy" do
    def validate(state: "Alert")
      url = "https://api.datadoghq.com/api/v1/monitor/123?api_key=dapikey&application_key=dappkey&group_states=alert"
      stub_request(:get, url).
        to_return(Array(state).map { |s| {body: {id: 123, overall_state: s, name: "Foo is down"}.to_json} })
      SamsonDatadog.validate_deploy(deploy, stub("Ex", output: out))
    end

    let(:out) { StringIO.new }
    let(:previous_deploy) { deploys(:succeeded_test) }
    let(:validate_deploy) { deploys(:succeeded_production_test) }
    let(:deploy) do
      project = previous_deploy.project
      job = Job.create!(status: "running", user: previous_deploy.user, project: project, command: "ls")
      Deploy.create!(
        stage: previous_deploy.stage,
        project: project,
        reference: "master",
        job: job
      )
    end

    before do
      deploy.job.commit = "a" * 40
      monitor = DatadogMonitor.new(123, overall_state: "OK")
      monitor.query = DatadogMonitorQuery.new(failure_behavior: "fail_deploy")
      deploy.datadog_monitors_for_validation = [monitor]
      SamsonDatadog.stubs(:sleep).with { raise "Unexpected sleep" }
    end

    it "fails when monitor was triggered" do
      validate.must_equal false
      out.string.must_equal <<~LOG
        Alert on datadog monitors:
        Foo is down https://app.datadoghq.com/monitors/123
      LOG
      refute deploy.redeploy_previous_when_failed
    end

    it "triggers redeploy when requested" do
      deploy.datadog_monitors_for_validation.first.query.failure_behavior = "redeploy_previous"
      validate.must_equal false
      out.string.must_equal <<~LOG
        Alert on datadog monitors:
        Foo is down https://app.datadoghq.com/monitors/123
        Trying to redeploy previous succeeded deploy
      LOG
      assert deploy.redeploy_previous_when_failed
    end

    it "raises on unknown failure_behavior" do
      deploy.datadog_monitors_for_validation.first.query.failure_behavior = "wut"
      assert_raises(ArgumentError) { validate }
    end

    it "passes when no monitors were captured" do
      deploy.datadog_monitors_for_validation.clear
      validate.must_equal true
      out.string.must_equal ""
    end

    it "passes when all monitors are still ok" do
      validate(state: "OK").must_equal true
      out.string.must_equal "No datadog monitors alerting\n"
    end

    it "passes when monitors are ok after their duration is elapsed" do
      SamsonDatadog.unstub(:sleep)
      SamsonDatadog.expects(:sleep).times(2)

      deploy.datadog_monitors_for_validation.first.query.check_duration = 120 # 2 min -> 2 loops
      validate(state: "OK").must_equal true
      out.string.must_equal <<~LOG
        No datadog monitors alerting 2 min remaining
        No datadog monitors alerting 1 min remaining
        No datadog monitors alerting
      LOG
    end

    it "fails when monitors fail after a duration" do
      SamsonDatadog.unstub(:sleep)
      SamsonDatadog.expects(:sleep).times(2)

      deploy.datadog_monitors_for_validation.first.query.check_duration = 180 # 3 min -> 3 loops, but stops early
      validate(state: ["OK", "OK", "Alert"]).must_equal false
      out.string.must_equal <<~LOG
        No datadog monitors alerting 3 min remaining
        No datadog monitors alerting 2 min remaining
        Alert on datadog monitors:
        Foo is down https://app.datadoghq.com/monitors/123
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

  describe :validate_deploy do
    only_callbacks_for_plugin :validate_deploy

    it 'sends notification on after hook' do
      Samson::Hooks.fire(:validate_deploy, deploy, stub(output: nil)).must_equal [true]
    end
  end
end

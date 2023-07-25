# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe DatadogMonitor do
  def assert_datadog(status: 200, times: 1, **params, &block)
    assert_request(
      :get, monitor_url,
      to_return: {body: api_response.merge(params).to_json, status: status},
      times: times,
      &block
    )
  end

  def assert_datadog_timeout(&block)
    assert_request(:get, monitor_url, to_timeout: [], &block)
  end

  let(:monitor) { DatadogMonitor.new(123) }
  let(:monitor_url) do
    "https://api.datadoghq.com/api/v1/monitor/123?api_key=dapikey&application_key=dappkey&group_states=alert,warn"
  end
  let(:api_response) do
    {
      name: "Monitor Slow foo",
      query: "max(last_30m):max:foo.metric.time.max{*} > 20000",
      overall_state: "Ok",
      type: "metric alert",
      message: "This is mostly informative... @foo@bar.com",
      org_id: 1234,
      id: 123,
      options: {notify_no_data: false, no_data_timeframe: 60, notify_audit: false, silenced: {}}
    }
  end
  let(:alerting_groups) { {state: {groups: {"pod:pod1": {status: "Alert"}}}} }

  describe "#state" do
    let(:groups) { [deploy_groups(:pod1), deploy_groups(:pod2)] }

    before { monitor.query = DatadogMonitorQuery.new(match_target: "pod", match_source: "deploy_group.permalink") }

    it "returns simple state when asking for global state" do
      assert_datadog(overall_state: "OK") do
        monitor.state([]).must_equal "OK"
      end
    end

    it "returns simple state when match_source was not set" do
      assert_datadog(overall_state: "OK") do
        monitor.query.match_source = ""
        monitor.state(groups).must_equal "OK"
      end
    end

    it "shows unknown using fallback monitor" do
      assert_datadog overall_state: nil do
        monitor.state(groups).must_be_nil
      end
    end

    it "shows OK when groups are not alerting" do
      assert_datadog(state: {groups: {}}) do
        monitor.state(groups).must_equal "OK"
      end
    end

    it "shows Alert when groups are alerting" do
      assert_datadog alerting_groups do
        monitor.state(groups).must_equal "Alert"
      end
    end

    it "shows Alert when nested groups are alerting" do
      assert_datadog(state: {groups: {"foo:bar,pod:pod1,bar:foo": {status: "Alert"}}}) do
        monitor.state(groups).must_equal "Alert"
      end
    end

    it "shows Warn when nested groups are warning" do
      assert_datadog(state: {groups: {"foo:bar,pod:pod1,bar:foo": {status: "Warn"}}}) do
        monitor.state(groups).must_equal "Warn"
      end
    end

    it "shows Warn when nested groups are alerting and warning" do
      state_groups = {
        "foo:bar1,pod:pod1,bar:foo": {status: "Warn"},
        "foo:bar2,pod:pod1,bar:foo": {status: "Alert"},
        "foo:bar3,pod:pod1,bar:foo": {status: "Warn"}
      }
      assert_datadog(state: {groups: state_groups}) do
        monitor.state(groups).must_equal "Alert"
      end
    end

    it "shows OK when other groups are alerting" do
      assert_datadog(state: {groups: {"pod:pod3": {status: "Alert"}}}) do
        monitor.state(groups).must_equal "OK"
      end
    end

    it "raises on unknown source" do
      assert_datadog(state: {groups: {"pod:pod3": {status: "Alert"}}}) do
        monitor.query.match_source = "wut"
        assert_raises(ArgumentError) { monitor.state(groups) }
      end
    end

    it "produces no extra sql queries" do
      stage = stages(:test_production) # preload
      assert_sql_queries 1 do # group-stage and groups
        assert_datadog alerting_groups do
          monitor.state(stage.deploy_groups)
        end
      end
    end

    it "runs no sql query when there are no alerts" do
      stage = stages(:test_production) # preload
      assert_sql_queries 0 do
        assert_datadog(state: {groups: {}}) do
          monitor.state(stage.deploy_groups)
        end
      end
    end

    it "can match on environment" do
      monitor.query.match_source = "environment.permalink"
      assert_datadog(state: {groups: {"pod:production": {status: "Alert"}}}) do
        monitor.state(groups).must_equal "Alert"
      end
    end

    it "can match on deploy_group.env_value" do
      monitor.query.match_source = "deploy_group.env_value"
      assert_datadog(state: {groups: {"pod:pod1": {status: "Alert"}}}) do
        monitor.state(groups).must_equal "Alert"
      end
    end

    describe "cluster matching" do
      before { monitor.query.match_source = "kubernetes_cluster.permalink" }

      it "can query by cluster" do
        assert_datadog(state: {groups: {"pod:foo1": {status: "Alert"}}}) do
          groups.each { |g| g.kubernetes_cluster.name = "Foo 1" }
          monitor.state(groups).must_equal "Alert"
        end
      end

      it "ignores missing clusters" do
        assert_datadog(state: {groups: {"pod:foo1": {status: "Alert"}}}) do
          groups.each { |g| g.kubernetes_cluster = nil }
          monitor.state(groups).must_equal "OK"
        end
      end
    end
  end

  describe "#name" do
    it "is there" do
      assert_datadog(overall_state: "OK") do
        monitor.name.must_equal "Monitor Slow foo"
      end
    end

    it "is error when request times out" do
      Samson::ErrorNotifier.expects(:notify)
      assert_datadog_timeout do
        silence_stderr { monitor.name.must_equal "api error" }
      end
    end

    it "is error when request fails" do
      assert_datadog(overall_state: "OK", status: 404) do
        silence_stderr { monitor.name.must_equal "api error" }
      end
    end
  end

  describe "#url" do
    it "builds a url" do
      monitor.url([]).must_equal "https://app.datadoghq.com/monitors/123"
    end

    describe "with match source" do
      before { monitor.query = DatadogMonitorQuery.new(match_source: "deploy_group.permalink", match_target: "pod") }

      it "builds a url for exact matches" do
        monitor.url([deploy_groups(:pod100)]).must_equal "https://app.datadoghq.com/monitors/123?q=pod%3Apod100"
      end

      it "does not build urls when multiple tags need to match" do
        monitor.url([deploy_groups(:pod100), deploy_groups(:pod1)]).must_equal "https://app.datadoghq.com/monitors/123"
      end
    end
  end

  describe "caching" do
    it "caches the api response" do
      assert_datadog(overall_state: "OK") do
        2.times { monitor.name }
      end
    end

    it "expires the cache when reloaded" do
      assert_datadog(overall_state: "OK", times: 2) do
        monitor.name
        monitor.reload_from_api
        monitor.name
      end
    end
  end

  describe ".list" do
    let(:url) do
      "https://api.datadoghq.com/api/v1/monitor?api_key=dapikey&application_key=dappkey&group_states=alert,warn&monitor_tags="
    end

    it "finds all" do
      assert_request(:get, url, to_return: {body: [{id: 1, name: "foo"}].to_json}) do
        DatadogMonitor.list("").map(&:name).must_equal ["foo"]
      end
    end

    it "can ignore by id" do
      body = [{id: 1, name: "foo"}, {id: 12345, name: "bar"}].to_json
      assert_request(:get, "#{url}foo,bar", to_return: {body: body}) do
        DatadogMonitor.list("foo,-12345,bar").map(&:name).must_equal ["foo"]
      end
    end

    it "adds tags" do
      assert_request(:get, "#{url}foo,bar", to_return: {body: [{id: 1, name: "foo"}].to_json}) do
        DatadogMonitor.list("foo,bar").map(&:id).must_equal [1]
      end
    end

    it "shows api error in the UI when it times out" do
      Samson::ErrorNotifier.expects(:notify)
      assert_request(:get, url, to_timeout: []) do
        DatadogMonitor.list("").map(&:name).must_equal ["api error"]
      end
    end

    it "shows api error in the UI when it fails" do
      Samson::ErrorNotifier.expects(:notify)
      assert_request(:get, url, to_return: {status: 500}) do
        DatadogMonitor.list("").map(&:name).must_equal ["api error"]
      end
    end
  end
end

# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe AcceptsDatadogMonitorQueries do
  let(:stage) { Stage.new(project: Project.new) }

  describe "#all_datadog_monitor_queries" do
    it "has them for project" do
      Project.new.all_datadog_monitor_queries
    end
  end

  describe "#datadog_monitors?" do
    it "is false when there are no monitors" do
      refute stage.datadog_monitors?
    end

    it "is true when there are monitors" do
      stage.datadog_monitor_queries.build
      assert stage.datadog_monitors?
    end
  end

  describe "#datadog_monitors" do
    let(:base_url) { "https://api.datadoghq.com/api/v1" }
    let(:monitor_url) { "#{base_url}/monitor/123?api_key=dapikey&application_key=dappkey&group_states=alert,warn" }

    it "is empty" do
      stage.datadog_monitors.must_equal []
    end

    it "is returns monitors" do
      stub_request(:get, monitor_url).
        to_return(body: {name: 'x'}.to_json)
      stage.datadog_monitor_queries_attributes = {0 => {query: "123"}}
      stage.datadog_monitors.map(&:name).must_equal ['x']
    end

    it "is returns monitors when it fails" do
      Samson::ErrorNotifier.expects(:notify)
      stub_request(:get, monitor_url)
      stage.datadog_monitor_queries_attributes = {0 => {query: "123"}}
      stage.datadog_monitors.map(&:id).must_equal [123]
    end

    it "can exclude monitors without failure behavior to avoid unnecessary queries" do
      stub_request(:get, monitor_url).
        to_return(body: {name: 'x'}.to_json)
      stage.datadog_monitor_queries_attributes = {0 => {query: "222"}, 1 => {query: "123", failure_behavior: "foo"}}
      stage.datadog_monitors(with_failure_behavior: true).map(&:id).must_equal [123]
    end
  end
end

# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Stage do
  let(:stage) { Stage.new(project: Project.new) }

  describe "#datadog_monitors" do
    let(:base_url) { "https://api.datadoghq.com/api/v1" }

    it "is empty" do
      stage.datadog_monitors.must_equal []
    end

    it "is returns monitors" do
      stub_request(:get, "#{base_url}/monitor/123?api_key=dapikey&application_key=dappkey&group_states=alert").
        to_return(body: {name: 'x'}.to_json)
      stage.datadog_monitor_queries_attributes = {0 => {query: "123"}}
      stage.datadog_monitors.map(&:name).must_equal ['x']
    end

    it "is includes project monitors" do
      stub_request(:get, "#{base_url}/monitor/123?api_key=dapikey&application_key=dappkey&group_states=alert").
        to_return(body: {name: 'x'}.to_json)
      stage.project.datadog_monitor_queries_attributes = {0 => {query: "123"}}
      stage.datadog_monitors.map(&:id).must_equal [123]
    end

    it "is returns monitors when it fails" do
      Samson::ErrorNotifier.expects(:notify)
      stub_request(:get, "#{base_url}/monitor/123?api_key=dapikey&application_key=dappkey&group_states=alert")
      stage.datadog_monitor_queries_attributes = {0 => {query: "123"}}
      stage.datadog_monitors.map(&:id).must_equal [123]
    end

    it "can exclude monitors without failure behavior to avoid unnecessary queries" do
      stub_request(:get, "#{base_url}/monitor/123?api_key=dapikey&application_key=dappkey&group_states=alert").
        to_return(body: {name: 'x'}.to_json)
      stage.datadog_monitor_queries_attributes = {0 => {query: "222"}, 1 => {query: "123", failure_behavior: "foo"}}
      stage.datadog_monitors(with_failure_behavior: true).map(&:id).must_equal [123]
    end
  end

  describe "#datadog_tags_as_array" do
    it "is empty" do
      stage.datadog_tags_as_array.must_equal []
    end

    it "works when not stripping" do
      stage.datadog_tags = " foo;bar;baz"
      stage.datadog_tags_as_array.must_equal ["foo", "bar", "baz"]
    end

    it "returns an array of the tags" do
      stage.datadog_tags = " foo; bar; baz "
      stage.datadog_tags_as_array.must_equal ["foo", "bar", "baz"]
    end

    it "uses only semicolon as separate" do
      stage.datadog_tags = " foo bar: baz "
      stage.datadog_tags_as_array.must_equal ["foo bar: baz"]
    end

    it "returns an empty array if no tags have been configured" do
      stage.datadog_tags = nil
      stage.datadog_tags_as_array.must_equal []
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
end

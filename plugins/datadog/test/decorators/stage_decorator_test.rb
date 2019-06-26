# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Stage do
  let(:stage) { Stage.new }

  describe "#datadog_monitors" do
    it "is empty" do
      Stage.new.datadog_monitors.must_equal []
    end

    it "is returns monitors" do
      stub_request(:get, "https://api.datadoghq.com/api/v1/monitor/123?api_key=dapikey&application_key=dappkey").
        to_return(body: {name: 'x'}.to_json)
      Stage.new(datadog_monitor_queries_attributes: {0 => {query: "123"}}).datadog_monitors.map(&:name).must_equal ['x']
    end

    it "is returns monitors when it fails" do
      Samson::ErrorNotifier.expects(:notify)
      stub_request(:get, "https://api.datadoghq.com/api/v1/monitor/123?api_key=dapikey&application_key=dappkey")
      Stage.new(datadog_monitor_queries_attributes: {0 => {query: "123"}}).datadog_monitors.map(&:id).must_equal [123]
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
end

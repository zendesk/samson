# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Stage do
  let(:stage) { Stage.new(project: Project.new) }

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

  describe "#datadog_monitors" do
    let(:base_url) { "https://api.datadoghq.com/api/v1" }
    let(:monitor_url) { "#{base_url}/monitor/123?api_key=dapikey&application_key=dappkey&group_states=alert,warn" }

    it "is empty" do
      stage.datadog_monitors.must_equal []
    end

    it "is includes project monitors" do
      stub_request(:get, monitor_url).
        to_return(body: {name: 'x'}.to_json)
      stage.project.datadog_monitor_queries_attributes = {0 => {query: "123"}}
      stage.datadog_monitors.map(&:id).must_equal [123]
    end
  end
end

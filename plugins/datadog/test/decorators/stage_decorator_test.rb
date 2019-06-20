# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Stage do
  let(:stage) { Stage.new }

  describe "#datadog_monitors" do
    it "is empty" do
      Stage.new.datadog_monitors.must_equal []
    end

    it "splits multiple monitors" do
      stage = Stage.new(datadog_monitor_ids: "1,2, 3")
      stage.datadog_monitors.map(&:id).must_equal [1, 2, 3]
    end
  end

  describe "#datadog_tags_as_array" do
    it "is empty" do
      stage.datadog_tags_as_array.must_equal []
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

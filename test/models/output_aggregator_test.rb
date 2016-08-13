# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe OutputAggregator do
  it "aggregates the output into a single string" do
    output = ["hel", "lo", "\n", "world\n"].map { |x| [:message, x] }
    aggregator = OutputAggregator.new(output)
    aggregator.to_s.must_equal "hello\nworld\n"
  end

  it "replaces lines correctly" do
    output = [[:message, "hello\rworld\n"]]
    aggregator = OutputAggregator.new(output)
    aggregator.to_s.must_equal "world\n"
  end
end

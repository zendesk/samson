require 'test_helper'

describe OutputAggregator do
  it "aggregates the output into a single string" do
    output = ["hel", "lo", "\n", "world\n"]
    aggregator = OutputAggregator.new(output)
    aggregator.to_s.must_equal "hello\nworld\n"
  end

  it "replaces lines correctly" do
    output = ["hello\rworld\n"]
    aggregator = OutputAggregator.new(output)
    aggregator.to_s.must_equal "world\n"
  end
end

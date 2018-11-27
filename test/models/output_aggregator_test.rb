# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe OutputAggregator do
  let(:output) { OutputBuffer.new }

  before { Time.stubs(:now).returns Time.parse('2018-01-01') }

  it "fails when output is still open and would hang forever" do
    assert_raises(RuntimeError) { OutputAggregator.new(output) }
  end

  it "aggregates the output into a single string" do
    ["hel", "lo", "\n", "world\n"].map { |x| output.write x }
    output.close
    aggregator = OutputAggregator.new(output)
    aggregator.to_s.must_equal "[00:00:00] hello\n[00:00:00] world\n"
  end

  it "replaces lines correctly" do
    output.write "hello\rworld\n"
    output.close
    aggregator = OutputAggregator.new(output)
    aggregator.to_s.must_equal "world\n"
  end

  it "only shows latest when message was replaced" do
    output.write "foo"
    output.write "bar\n"
    output.write "baz\n", :replace
    output.puts "baz2"
    output.close
    aggregator = OutputAggregator.new(output)
    aggregator.to_s.must_equal "[00:00:00] baz\n[00:00:00] baz2\n"
  end

  it "ignores other events" do
    output.write "hello\n"
    output.write "world\n", :finished
    output.close
    aggregator = OutputAggregator.new(output)
    aggregator.to_s.must_equal "[00:00:00] hello\n"
  end
end

# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe JobViewers do
  let(:output) { OutputBuffer.new }
  let(:viewer) { JobViewers.new(output) }

  describe "#push" do
    it "adds an item and notifies the output" do
      viewer.push :foo
      viewer.instance_variable_get(:@list).must_equal [:foo]
      output.instance_variable_get(:@previous).must_equal [[:viewers, viewer]]
    end
  end

  describe "#delete" do
    it "deletes an item and notifies the output" do
      viewer.push :foo
      viewer.push :bar
      viewer.delete :foo
      viewer.instance_variable_get(:@list).must_equal [:bar]
      output.instance_variable_get(:@previous).must_equal [[:viewers, viewer], [:viewers, viewer], [:viewers, viewer]]
    end
  end

  describe "#to_a" do
    it "generates a dup" do
      viewer.to_a.object_id.wont_equal viewer.instance_variable_get(:@list).object_id
    end
  end
end

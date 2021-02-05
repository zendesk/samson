# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Samson::Parallelizer do
  describe ".map" do
    it "does not produce threads when nothing is to do" do
      Thread.expects(:new).never
      Samson::Parallelizer.map([]).must_equal []
    end

    it "can handle non-arrays" do
      Samson::Parallelizer.map([1].each_slice(2)) { |x| x }.must_equal [[1]]
    end

    it "works in reused threads" do
      list = []
      Samson::Parallelizer.map(Array.new(20)) do
        list << Thread.current.object_id
        Thread.pass
        sleep 0.05
      end
      list.uniq.size.must_equal 10
    end

    it "works" do
      Samson::Parallelizer.map([1, 2, 3]) { |i| i + 3 }.must_equal [4, 5, 6]
    end

    it "can connect to the db" do
      count = User.count
      Samson::Parallelizer.map([1, 2, 3], db: true) { User.count }.must_equal [count, count, count]
    end

    it "re-raises exceptions outside the thread" do
      e = assert_raises RuntimeError do
        Samson::Parallelizer.map([1, 2, 3]) { raise "foo" } # rubocop:disable Lint/UnreachableLoop
      end
      e.message.must_equal "foo"
    end
  end
end

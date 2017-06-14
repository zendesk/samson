# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Samson::Parallelizer do
  describe ".map" do
    it "does not produce threads when nothing is to do" do
      Thread.expects(:new).never
      Samson::Parallelizer.map([]).must_equal []
    end

    it "does not produce threads when serial work is equally fast" do
      Thread.expects(:new).never
      Samson::Parallelizer.map([1]) { 2 }.must_equal [2]
    end

    it "produces maximum amount of threads" do
      Thread.expects(:new).times(10).returns([])
      Samson::Parallelizer.map(Array.new(20)) { 1 }.must_equal(Array.new(20))
    end

    it "works in reused threads" do
      list = []
      Samson::Parallelizer.map(Array.new(20)) do
        list << Thread.current.object_id
        Thread.pass
        sleep 0.01
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
  end
end

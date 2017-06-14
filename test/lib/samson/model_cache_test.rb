# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Samson::ModelCache do
  describe ".track" do
    it "auto-triggers" do
      Lock.name
      Samson::ModelCache.instance_variable_get(:@caches).keys.must_include(:Lock)
    end
  end

  describe ".cache" do
    it "caches" do
      calls = []
      3.times { Samson::ModelCache.cache(Lock, :foo) { calls << 1 }.must_equal [1] }
      calls.must_equal [1]
    end

    it "caches nil" do
      calls = []
      3.times { Samson::ModelCache.cache(Lock, :foo) { calls << 1; nil }.must_equal nil }
      calls.must_equal [1]
    end

    it "can expire" do
      calls = []
      Samson::ModelCache.cache(Lock, :foo) { calls << 1 }
      Lock.create! user: users(:admin)
      Samson::ModelCache.cache(Lock, :foo) { calls << 2 }
      calls.must_equal [1, 2]
    end
  end

  describe ".expire" do
    it "can expire all" do
      calls = []
      Samson::ModelCache.cache(Lock, :foo) { calls << 1 }
      Samson::ModelCache.expire
      Samson::ModelCache.cache(Lock, :foo) { calls << 2 }
      calls.must_equal [1, 2]
    end
  end
end

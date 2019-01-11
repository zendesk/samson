# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Samson::DynamicTtlCache do
  describe "#cache_fetch_if" do
    it "fetches old" do
      Rails.cache.write('a', 1)
      Samson::DynamicTtlCache.cache_fetch_if(true, 'a', expires_in: :raise) { 2 }.must_equal 1
    end

    it "does not cache when not requested" do
      Rails.cache.write('a', 1)
      Samson::DynamicTtlCache.cache_fetch_if(false, 'a', expires_in: :raise) { 2 }.must_equal 2
      Rails.cache.read('a').must_equal 1
    end

    it "caches with expiration" do
      Samson::DynamicTtlCache.cache_fetch_if(true, 'a', expires_in: ->(_) { 1 }) { 2 }.must_equal 2
      Rails.cache.read('a').must_equal 2
    end

    it "does not cache when user did not want it cached" do
      Rails.cache.expects(:write).never
      Samson::DynamicTtlCache.cache_fetch_if(true, 'a', expires_in: ->(_) { 0 }) { 2 }.must_equal 2
    end
  end
end

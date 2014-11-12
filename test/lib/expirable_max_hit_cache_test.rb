require_relative '../test_helper'

describe ExpirableMaxHitCache do

  before(:each) do
    ExpirableMaxHitCache.instance.invalidate_references_cache('key')
    ExpirableMaxHitCache.instance.reset_lookup_count('key')
  end

  it 'guarantees that the cache returns the value in the block' do
    result = ExpirableMaxHitCache.instance.fetch('key', 10.seconds) { 'test_value' }
    result.must_equal 'test_value'
  end

  it 'guarantees that after the threshold it fetches the value again' do
    counter = 0
    (0..6).each { ExpirableMaxHitCache.instance.fetch('key', 30.minutes) { counter += 1 } }
    counter.must_equal(2)
    ExpirableMaxHitCache.instance.instance_variable_get(:@cache_hits)['key'].must_equal 1
  end

  it 'guarantees that if the block returns nil it the cache will execute the block again' do
    counter = 0
    ExpirableMaxHitCache.instance.fetch('key', 30.minutes) { counter += 1; nil }
    ExpirableMaxHitCache.instance.fetch('key', 30.minutes) { counter += 1; nil }
    counter.must_equal(2)
  end

end

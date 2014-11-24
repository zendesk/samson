class ExpirableMaxHitCache
  include Singleton

  def initialize
    @cache_hits = {}
  end

  def fetch(key, ttl, hit_threshold=5, &block)
    @cache_hits[key] = 0 unless @cache_hits[key]
    hit_count = @cache_hits[key] if @cache_hits[key]
    if hit_count > hit_threshold
      invalidate_references_cache(key)
      reset_lookup_count(key)
    end
    cached_value = fetch_cached_value(key, ttl, &block)
    increase_lookup_count(key)
    cached_value
  end

  def invalidate_references_cache(key)
    Rails.cache.delete(key)
  end

  def reset_lookup_count(key)
    @cache_hits[key] = 0
  end

  private

  def increase_lookup_count(key)
    @cache_hits[key] += 1
  end

  def fetch_cached_value(key , ttl, &block)
    Rails.cache.fetch(key, :expires_in => ttl) do
      reset_lookup_count(key)
      block.call
    end
  end

end

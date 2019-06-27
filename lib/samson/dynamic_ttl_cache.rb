# frozen_string_literal: true

module Samson
  class DynamicTtlCache
    class << self
      def cache_fetch_if(condition, key, expires_in:)
        return yield unless condition

        old = Rails.cache.read(key)
        return old if old

        current = yield
        expires_in = expires_in.call(current)
        Rails.cache.write(key, current, expires_in: expires_in) unless expires_in == 0
        current
      end
    end
  end
end

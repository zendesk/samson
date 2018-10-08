# frozen_string_literal: true
module Samson
  module ExtraDig
    def dig_fetch(*keys, last, &block)
      block ||= ->(*) { raise KeyError, "key not found: #{(keys << last).inspect}" }
      before = (keys.any? ? dig(*keys) || {} : self)
      before.fetch(last, &block)
    end

    def dig_set(keys, value)
      raise ArgumentError, "No key given" if keys.empty?
      keys = keys.dup
      last = keys.pop
      failed = ->(*) { raise KeyError, "key not found: #{keys.inspect}" }
      nested = keys.inject(self) { |h, k| h.fetch(k, &failed) }
      nested[last] = value
    end
  end
end

# frozen_string_literal: true
module Samson
  module BumpTouch
    def bump_touch
      new = Time.now
      new += 1 if new.to_i == updated_at.to_i
      update_column(:updated_at, new)
    end
  end
end

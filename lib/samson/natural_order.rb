# frozen_string_literal: true
module Samson
  module NaturalOrder
    # split words into string and numbers to better sort them "a1b2" -> ["a", 1, "b", 2]
    # this avoids pod2 being sorted after pod10
    def self.convert(name)
      name.split(/(\d+)/).each_with_index.map { |x, i| i.odd? ? x.to_i : x }
    end

    def self.name_sortable(name)
      name.split(/(\d+)/).each_with_index.map { |x, i| i.odd? ? x.rjust(5, "0") : x }.join
    end
  end
end

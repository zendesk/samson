# frozen_string_literal: true

module Samson
  module OutputUtils
    def self.timestamp
      "[#{Time.now.utc.strftime("%T")}]"
    end
  end
end

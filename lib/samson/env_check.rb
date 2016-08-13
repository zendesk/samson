# frozen_string_literal: true
module Samson
  module EnvCheck
    FALSE = Set.new(['0', 'false', nil, ''])

    def self.set?(k)
      !FALSE.include?(ENV[k])
    end
  end
end

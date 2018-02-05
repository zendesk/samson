# frozen_string_literal: true
require 'parallel'

module Samson
  class Parallelizer
    class << self
      def map(elements, db: false)
        Parallel.map(elements, in_threads: 10) do |e|
          if db
            ActiveRecord::Base.connection_pool.with_connection { yield e }
          else
            yield e
          end
        end
      end
    end
  end
end

# frozen_string_literal: true
module Samson
  class Parallelizer
    class << self
      def map(elements, db: false)
        max = elements.size
        return [] if max.zero?
        return [yield(elements.first)] if max == 1

        mutex = Mutex.new
        current = -1
        results = Array.new(max)

        Array.new([max, 10].min).map do
          Thread.new do
            with_db_connection(db) do
              loop do
                working_index = mutex.synchronize { current += 1 }
                break if working_index >= max
                results[working_index] = yield elements[working_index]
              end
            end
          end
        end.map(&:join)

        results
      end

      private

      def with_db_connection(needed, &block)
        if needed
          ActiveRecord::Base.connection_pool.with_connection(&block)
        else
          yield
        end
      end
    end
  end
end

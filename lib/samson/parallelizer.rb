# frozen_string_literal: true
module Samson
  class Parallelizer
    class << self
      def map(elements, db: false)
        raise ArgumentError, "argument must be arrayish" unless elements.respond_to?(:[])

        max = elements.size
        return [] if max.zero?
        return [yield(elements[0])] if max == 1

        mutex = Mutex.new
        current = -1
        results = Array.new(max)
        exception = nil

        Array.new([max, 10].min).map do
          Thread.new do
            begin
              with_db_connection(db) do
                loop do
                  working_index = mutex.synchronize { current += 1 }
                  break if working_index >= max || exception
                  results[working_index] = yield elements[working_index]
                end
              end
            rescue
              exception = $!
            end
          end
        end.map(&:join)

        raise exception if exception

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

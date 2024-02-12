# frozen_string_literal: true
module MultiThreadDbDetector
  class << self
    def in_with_connection
      Thread.current[:in_with_connection]
    end

    def in_with_connection=(v)
      Thread.current[:in_with_connection] = v
    end
  end
end

# alert when we would accidentally use a connection that is not rolled back with the current
# transaction and would pollute the DB for the subsequent tests
ActiveRecord::ConnectionAdapters::AbstractAdapter.prepend(
  Module.new do
    def log(*)
      if Thread.current != Thread.main && !MultiThreadDbDetector.in_with_connection
        raise "Using AR outside the main thread and not inside a with_connection block, this will break the transaction"
      else
        super
      end
    end
  end
)

ActiveRecord::ConnectionAdapters::ConnectionPool.prepend(
  Module.new do
    def with_connection
      old = MultiThreadDbDetector.in_with_connection
      MultiThreadDbDetector.in_with_connection = true
      super
    ensure
      MultiThreadDbDetector.in_with_connection = old
    end
  end
)

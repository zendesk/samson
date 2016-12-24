# frozen_string_literal: true
module MultiThreadDbDetector
  class << self
    attr_accessor :in_with_connection
  end
end

# alert when we would accidentally use a connection that is not rolled back with the current
# transaction and would pollute the DB for the subsequent tests
# cannot use prepend since QueryDiet uses alias_method and that ends in a infinite loop
ActiveRecord::ConnectionAdapters::AbstractAdapter.class_eval do
  alias_method :log_without_foo, :log
  def log(*args, &block)
    if Thread.current != Thread.main && !MultiThreadDbDetector.in_with_connection
      raise "Using AR outside the main thread and not inside a with_connection block, this will break the transaction"
    else
      log_without_foo(*args, &block)
    end
  end
end

ActiveRecord::ConnectionAdapters::ConnectionPool.prepend(Module.new do
  def with_connection
    MultiThreadDbDetector.in_with_connection = true
    super
  ensure
    MultiThreadDbDetector.in_with_connection = false
  end
end)

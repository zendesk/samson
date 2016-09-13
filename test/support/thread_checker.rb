# frozen_string_literal: true

ActiveSupport::TestCase.class_eval do
  before do
    @before_threads = Thread.list
  end

  after { fail_if_dangling_threads }

  def fail_if_dangling_threads
    max_threads = 1 # Timeout.timeout adds a thread
    raise "Test left dangling threads: #{extra_threads}" if extra_threads.count > max_threads
  ensure
    kill_extra_threads
  end

  def wait_for_threads
    sleep 0.1 while extra_threads.any?
  end

  def kill_extra_threads
    extra_threads.map(&:kill).map(&:join)
  end

  def extra_threads
    if @before_threads
      Thread.list - @before_threads
    else
      []
    end
  end
end

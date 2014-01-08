require 'thread_safe'

class JobOutput
  attr_reader :messages

  class Subscriber
    attr_reader :queue

    def initialize
      @queue = Queue.new
    end

    def message(message, &block)
      @on_message.try(:call, message)
    end

    def close
      @on_close.try(:call)
    end

    def on_message(&block)
      @on_message = block
    end

    def on_close(&block)
      @on_close = block
    end
  end

  def initialize
    @listeners = ThreadSafe::Array.new
    @messages = ThreadSafe::Array.new
  end

  def push(message)
    @messages << message
    @listeners.each {|listener| listener.queue.push(message)}
  end

  def to_s
    @messages.join("\n")
  end

  def close
    @listeners.each(&:close)
  end

  def subscribe
    subscriber = Subscriber.new
    @listeners << subscriber

    yield subscriber

    @messages.each do |message|
      subscriber.message(message)
    end

    while (message = subscriber.queue.pop)
      subscriber.message(message)
    end
  ensure
    @listeners.delete(subscriber)
  end
end

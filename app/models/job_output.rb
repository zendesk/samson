require 'thread_safe'

class JobOutput
  CLOSE = Object.new

  attr_reader :messages

  def initialize
    @listeners = ThreadSafe::Array.new
    @messages = ThreadSafe::Array.new
    @closed = false
  end

  def push(message)
    @messages << message unless message == CLOSE
    @listeners.each {|listener| listener.push(message)}
  end

  def to_s
    @messages.join("\n")
  end

  def close
    @closed = true
    push(CLOSE)
  end

  def each(&block)
    return @messages.each(&block) if @closed

    queue = Queue.new
    @listeners << queue

    @messages.each {|message| yield message }

    while (message = queue.pop) && message != CLOSE
      yield message
    end
  ensure
    @listeners.delete(queue)
  end
end

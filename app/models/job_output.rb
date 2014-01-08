require 'thread_safe'

class JobOutput
  attr_reader :messages

  def initialize
    @listeners = ThreadSafe::Array.new
    @messages = ThreadSafe::Array.new
  end

  def push(message)
    @messages << message
    @listeners.each {|listener| listener.push(message)}
  end

  def to_s
    @messages.join("\n")
  end

  def each_message
    queue = Queue.new
    @listeners << queue

    @messages.each {|message| yield message }

    while (message = queue.pop)
      yield message
    end
  ensure
    @listeners.delete(queue)
  end
end

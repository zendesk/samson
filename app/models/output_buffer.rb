require 'thread_safe'

class OutputBuffer
  CLOSE = Object.new

  attr_reader :chunks

  def initialize
    @listeners = ThreadSafe::Array.new
    @chunks = ThreadSafe::Array.new
    @closed = false
  end

  def write(chunk)
    @chunks << chunk unless chunk == CLOSE
    @listeners.each {|listener| listener.push(chunk) }
  end

  def to_s
    chunks.join("\n")
  end

  def close
    @closed = true
    write(CLOSE)
  end

  def each(&block)
    return @chunks.each(&block) if @closed

    queue = Queue.new
    @listeners << queue

    @chunks.each {|chunk| yield chunk }

    while (chunk = queue.pop) && chunk != CLOSE
      yield chunk
    end
  ensure
    @listeners.delete(queue)
  end
end

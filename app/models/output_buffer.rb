require 'thread_safe'

# Allows fanning out a stream to multiple listening threads. Each thread will
# have to call `#each`, and will receive each chunk of data that is written
# to the buffer. If a thread starts listening after the buffer has been written
# to, it will receive the previous chunks immediately and then start streaming
# new chunks.
#
# Example:
#
#   buffer = OutputBuffer.new
#
#   listener1 = Thread.new { c = ""; buffer.each {|event, data| c << data }; c }
#   listener2 = Thread.new { c = ""; buffer.each {|event, data| c << data }; c }
#
#   buffer.write("hello ")
#   buffer.write("world!")
#   buffer.close
#
#   listener1.value #=> "hello world!"
#   listener2.value #=> "hello world!"
#
class OutputBuffer
  attr_reader :listeners

  def initialize
    @listeners = ThreadSafe::Array.new
    @previous = ThreadSafe::Array.new
    @closed = false
  end

  def puts(line)
    write(line.rstrip + "\n")
  end

  def write(data, event = :message)
    @previous << [event, data] unless event == :close
    @listeners.dup.each {|listener| listener.push([event, data]) }
  end

  def include?(event, data)
    @previous.include?([event, data])
  end

  def to_s
    @previous.select { |event, _data| event == :message }.map(&:last).join
  end

  def close
    return if closed?
    @closed = true
    write(nil, :close)
  end

  def closed?
    @closed
  end

  def each(&block)
    # If the buffer is closed, there's no reason to block the listening
    # thread - just yield all the buffered chunks and return.
    return @previous.each(&block) if closed?

    begin
      queue = Queue.new
      @listeners << queue

      @previous.each(&block) # race condition: possibly duplicate messages when message comes in between adding listener and this

      while (chunk = queue.pop) && chunk.first != :close
        yield chunk
      end
    ensure
      @listeners.delete(queue)
    end
  end
end

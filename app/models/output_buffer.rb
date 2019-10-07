# frozen_string_literal: true
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

  PADDING = " " * 11

  def initialize
    @listeners = ThreadSafe::Array.new
    @previous = ThreadSafe::Array.new
    @closed = false
    @line_finished = true
    @mutex = Mutex.new
  end

  def puts(line = "")
    write(line.to_s.rstrip << "\n")
  end

  def write(data, event = :message)
    if data.is_a?(String)
      data = inject_timestamp(data)
      if data.encoding != Encoding::UTF_8
        data = data.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
      end
    end

    @previous << [event, data]
    @listeners.dup.each { |listener| listener.push([event, data]) }
  end

  def include?(event, data)
    @previous.include?([event, data])
  end

  # incomplete / unparsed messages for inspection or grepping
  def messages
    @previous.select { |event, _data| event == :message }.map(&:last).join
  end

  # needs a mutex so we never add a new queue after closing since that would hang forever on the .pop
  def close
    @mutex.synchronize do
      @closed = true
      @listeners.each(&:close) # make .pop return nil
    end
  end

  def closed?
    @closed
  end

  # a new listener subscribes ...
  def each(&block)
    # If the buffer is closed, there's no reason to block the listening
    # thread, yield all the buffered chunks and return.
    queue = Queue.new
    @mutex.synchronize do
      return @previous.each(&block) if closed?
      @listeners << queue
    end

    # race condition: possibly duplicate messages when message comes in between adding listener and this
    @previous.each(&block)

    while chunk = queue.pop
      yield chunk
    end
  ensure
    @mutex.synchronize { @listeners.delete(queue) }
  end

  private

  # TODO: ideally the TerminalOutputScanner should handle this, but that would require us to record the timestamp
  def inject_timestamp(chunk)
    stamped = +""
    lines = chunk.each_line.to_a
    return stamped if lines.empty?

    append = !@line_finished
    @line_finished = lines.last.end_with?($/)
    stamped << lines.shift if append
    lines.each do |line|
      stamped << "#{Samson::OutputUtils.timestamp} #{line}"
    end
    stamped
  end
end

class TerminalOutputScanner
  def initialize(source)
    @source, @queue = source, []
    reset_buffer!
  end

  def each(&block)
    @source.each do |data|
      write(data)
      @queue.each(&block)
      @queue.clear
    end
  end

  private

  def write(data)
    data.scan(/\r?[^\r]*/).each do |part|
      next if part == ""
      write_part(part)
    end
  end

  def write_part(part)
    if part.start_with?("\r") || part.start_with?("\n")
      flush_buffer!

      part.sub!(/^\r/, "") # chop off the leading \r

      if part.start_with?("\n")
        @state = :append
      else
        @state = :replace
      end
    end

    @buffer << part

    if @buffer.end_with?("\n")
      flush_buffer!
    end
  end

  def flush_buffer!
    if !@buffer.empty?
      output(@state, @buffer)
      reset_buffer!
    end
  end

  def reset_buffer!
    @buffer = ""
    @state = :append
  end

  def output(event, data)
    @queue << [event, data]
  end
end

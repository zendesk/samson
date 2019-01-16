# frozen_string_literal: true
# Scans a stream of characters, yielding a stream of tokens.
#
# The scanner understands some terminal escape codes - in particular, it pays
# attention to newlines (`\n`) and carriage returns (`\r`). When a carriage
# return is encountered, the scanner's cursor is reset to the start of the
# current line, and the next data will overwrite that line.
#
# TODO: fix not returning buffer when source is empty, for example "foo\n" + "bar" does not return bar
class TerminalOutputScanner
  def initialize(source)
    @source = source
    @queue = []
    reset_buffer
  end

  def each(&block)
    @source.each do |event, data|
      if event == :message
        write(data)
      else
        output(event, data)
      end

      @queue.each(&block)
      @queue.clear
    end
  end

  private

  def write(data)
    clean_data = data.scrub.gsub("\r\n", "\n")
    clean_data.scan(/\r?[^\r]*/).each do |part|
      next if part == ''
      write_part(part)
    end
  end

  def write_part(part)
    if part.start_with?("\r", "\n")
      flush_buffer

      part.sub!(/^\r/, "") # chop off the leading \r

      @state =
        if part.start_with?("\n")
          :append
        else
          :replace
        end
    end

    @buffer << part

    flush_buffer if @buffer.end_with?("\n")
  end

  def flush_buffer
    unless @buffer.empty?
      output(@state, @buffer)
      reset_buffer
    end
  end

  def reset_buffer
    @buffer = +""
    @state = :append
  end

  def output(event, data)
    @queue << [event, data]
  end
end

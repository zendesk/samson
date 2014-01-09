class OutputStreamer
  def initialize(stream)
    @stream = stream
  end

  def start(output, &block)
    # Heartbeat thread until puma/puma#389 is solved
    start_heartbeat!
    output.each {|message| write_message(message, &block) }
  rescue IOError
    # Raised on stream close
  ensure
    stop_heartbeat!
    finished
  end

  def finished
    emit_event "finished"
    @stream.close
  end

  private

  def write_message(message, &block)
    lines = message.split("\r")
    block ||= proc {|x| x }

    emit_event "append", "\n" << block.call(lines.shift)

    lines.each do |line|
      emit_event "replace", block.call(line)
    end
  end

  def emit_event(name, data = "")
    json = data.present? ? JSON.dump(msg: data) : ""

    Rails.logger.debug data.inspect

    @stream.write("event: #{name}\ndata: #{json}\n\n")
  end

  def start_heartbeat!
    @heartbeat = Thread.new do
      begin
        while true
          @stream.write("data: \n\n")
          sleep(5) # Timeout of 5 seconds
        end
      rescue IOError
        finished
      end
    end
  end

  def stop_heartbeat!
    @heartbeat.try(:kill)
  end
end

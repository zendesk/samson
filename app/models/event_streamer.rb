class EventStreamer
  def initialize(stream)
    @stream = stream
  end

  def start(output, &block)
    block ||= proc {|x| x }

    # Heartbeat thread until puma/puma#389 is solved
    start_heartbeat!

    @scanner = TerminalOutputScanner.new(output)
    @scanner.each {|event, data| emit_event(event, block.call(data)) }
  rescue IOError
    # Raised on stream close
  ensure
    stop_heartbeat!
    finished
  end

  def finished
    emit_event "finished"
  rescue IOError
    # Raised on stream close
  ensure
    @stream.close
  end

  private

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

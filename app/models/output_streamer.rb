class OutputStreamer
  def initialize(stream)
    @stream = stream
  end

  def start(output)
    # Heartbeat thread until puma/puma#389 is solved
    start_heartbeat!
    output.each {|message| write_message(message) }
  rescue IOError
    # Raised on stream close
  ensure
    stop_heartbeat!
    finished
  end

  def finished
    @stream.write("event: finished\n")
    @stream.write("data: \n\n")
    @stream.close
  end

  private

  def write_message(message)
    data = JSON.dump(msg: message)
    @stream.write("event: output\n")
    @stream.write("data: #{data}\n\n")
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

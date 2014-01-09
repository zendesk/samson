class OutputStreamer
  def initialize(output, stream)
    @output, @stream = output, stream
  end

  def self.start(output, stream)
    new(output, stream).start
  end

  def start
    # Heartbeat thread until puma/puma#389 is solved
    start_heartbeat!
    @output.each_message {|message| write_message(message) }
  rescue IOError
    # Raised on stream close
  ensure
    stop_heartbeat!
    @stream.close
  end

  private

  def write_message(message)
    data = JSON.dump(msg: message)
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
        @stream.close
      end
    end
  end

  def stop_heartbeat!
    @heartbeat.try(:kill)
  end
end

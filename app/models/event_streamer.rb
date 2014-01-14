# Streams the terminal output events from a output source to a destination IO
# stream.
#
# The streamed data will be in the forms of Server Sent Event messages:
#
#   event: append
#   data: { "msg": "hello" }
#
#   event: replace
#   data: { "msg" {"world\n" }
#
# The `append` event is meant to insert a new line at the end of some client
# buffer while the `replace` event is meant to replace the last line of the
# client buffer with the data contained in the message.
#
# Example:
#
#   # `stream` is e.g. the response.stream object in a Rails controller.
#   streamer = EventStreamer.new(stream)
#
#   # `output` is anything that responds to `#each`. The block will be called
#   # with each chunk of data that is about to be streamed - its return value
#   # will be sent instead.
#   streamer.start(output) {|chunk| chunk.html_safe }
#
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

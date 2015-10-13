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
  def initialize(stream, &block)
    @stream = stream
    @handler = block || proc {|_, x|
      if x.present?
        JSON.dump(msg: x)
      else
        ''
      end
    }
  end

  def start(output)
    # Heartbeat thread until puma/puma#389 is solved
    start_heartbeat!

    @scanner = TerminalOutputScanner.new(output)
    @scanner.each {|event, data| emit_event(event, @handler.call(event, data)) }
  rescue IOError, ActionController::Live::ClientDisconnected
    # Raised on stream close
  ensure
    finished
  end

  def finished
    emit_event('finished', @handler.call(:finished, ''))
  rescue IOError, ActionController::Live::ClientDisconnected
    # Raised on stream close
  ensure
    ActiveRecord::Base.clear_active_connections!

    # Hackity-hack: clear out the buffer since
    # the heartbeat thread may be blocked waiting
    # to get into the queue or vice-versa
    sleep(2)

    buffer = @stream.instance_variable_get(:@buf)
    buffer.clear

    @stream.close
  end

  private

  def emit_event(name, data = "")
    Rails.logger.debug("#{name}: #{data.inspect}")
    @stream.write("event: #{name}\ndata: #{data}\n\n")
  end

  def start_heartbeat!
    Thread.new do
      begin
        while true
          @stream.write("data: \n\n")
          sleep(5) # Timeout of 5 seconds
        end
      rescue IOError, ActionController::Live::ClientDisconnected
        finished
      end
    end
  end
end

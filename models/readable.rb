require 'eventmachine'

class Readable < EventMachine::Connection
  IO_BUFFER_READ = 4096

  def initialize(callback)
    super

    @callback = callback
  end

  def notify_readable
    while buffer = @io.read_nonblock(IO_BUFFER_READ)
      @callback.call(buffer)
    end
  rescue IOError, EOFError, Errno::EAGAIN, Errno::EIO
  end
end

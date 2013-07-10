require 'eventmachine'

class Readable < EventMachine::Connection
  IO_BUFFER_READ = 4096

  def initialize(socket)
    super

    @socket = socket
  end

  def notify_readable
    while buffer = @io.read_nonblock(IO_BUFFER_READ)
      @socket.send(buffer)
    end
  rescue EOFError, Errno::EAGAIN
  end
end

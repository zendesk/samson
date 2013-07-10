require 'pty'

class CommandTail
  def initialize(command, &callback)
    @command = command
    @callback = callback

    @io, _, @pid = PTY.spawn(@command)

    @connection = EventMachine.watch(@io, Readable, @callback)
    @connection.notify_readable = true
  end

  def close
    Process.kill("INT", @pid)

    @callback.call(@io.read_nonblock(Readable::IO_BUFFER_READ))
  rescue EOFError
  ensure
    @connection.detach
    @io.close
  end
end

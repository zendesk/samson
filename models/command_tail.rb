require 'pty'

class CommandTail
  def initialize(command, callback, close_callback = nil)
    @command = command
    @callback, @close_callback = callback, close_callback

    @io, _, @pid = PTY.spawn(@command)

    @connection = EventMachine.watch(@io, Readable, @callback)
    @connection.notify_readable = true

    begin
      @process_connection = EventMachine.watch_process(@pid, Watchable, self)
    rescue EventMachine::Unsupported
    end
  end

  def exited
    @connection.detach
    @io.close unless @io.closed?
    @close_callback.call if @close_callback
  end

  def close
    if PTY.check(@pid).nil?
      @process_connection.stop_watching if @process_connection
      Process.kill("INT", @pid)
    end

    @connection.notify_readable

    exited
  end
end

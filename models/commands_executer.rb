class CommandsExecuter
  def initialize(commands, callback, final_callback = nil)
    @commands = commands
    @callback, @final_callback = callback, final_callback

    next_command
  end

  def next_command
    command = @commands.shift

    @callback.call("Executing \"#{command}\"...\n")

    final_callback = if @commands.any?
      proc { self.next_command }
    else
      proc { @final_callback.call }
    end

    @current_tail = CommandTail.new(command, @callback, final_callback)
  end

  def close
    @current_tail.close if @current_tail
  end
end

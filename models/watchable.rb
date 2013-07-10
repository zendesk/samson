require 'eventmachine'

class Watchable < EventMachine::ProcessWatch
  def initialize(command)
    super

    @command = command
  end

  def process_exited
    @command.exited
  end
end

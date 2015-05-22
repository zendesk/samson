module Samson
  class ShellScript
    delegate :stop!, :pid, to: :@executer
    attr_accessor :output

    def initialize(output, verbose: false)
      @output = output
      @verbose = verbose
      @executer = TerminalExecutor.new(output)
    end

    def execute!(*commands)
      command = create_command(commands)
      @executer.execute_command! command
    end

    private

    def create_command(commands)
      commands.map! { |c| "echo » #{c.shellescape}\n#{c}" } if @verbose
      commands.unshift("set -e")

      command = commands.join("\n")

      if RUBY_ENGINE == 'jruby'
        command = %Q{/bin/sh -c "#{command.gsub(/"/, '\\"')}"}
      end
      command
    end
  end
end

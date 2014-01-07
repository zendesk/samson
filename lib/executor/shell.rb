require_relative 'base'
require 'open3'

module Executor
  class Shell < Base
    def execute!(*commands)
      command = commands.map do |command|
        execute_command(command)
      end.join("\n")

      Open3.popen3(command) do |stdin, stdout, stderr, wait_thr|
        output_thr = Thread.new do
          stdout.each do |line|
            @callbacks[:stdout].each {|callback| callback.call(line)}
          end
        end

        error_thr = Thread.new do
          stderr.each do |line|
            @callbacks[:stderr].each {|callback| callback.call(line)}
          end
        end

        wait_thr.value.success?
      end
    # JRuby raises an IOError on a nonexistent first command
    rescue IOError => e
      @callbacks[:stderr].each {|callback| callback.call(error(commands.first))}
      false
    end

    private

    def execute_command(command)
      <<-G
#{command}
RETVAL=$?
if [ $RETVAL != 0 ];
then
  echo '#{error(command)}' >&2
  exit $RETVAL
fi
      G
    end

    def error(command)
      "Failed to execute \"#{command}\""
    end
  end
end

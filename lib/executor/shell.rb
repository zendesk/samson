require_relative 'base'
require 'open3'

module Executor
  class Shell < Base
    attr_reader :pid

    def execute!(*commands)
      command = commands.map do |command|
        execute_command(command)
      end.join("\n")

      stdin, stdout, stderr, wait_thr = Open3.popen3(command)
      @pid = wait_thr.pid

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
    # JRuby raises an IOError on a nonexistent first command
    rescue IOError => e
      @callbacks[:stderr].each {|callback| callback.call(error(commands.first))}
      false
    end

    def stop!
      # Need pkill because we want all
      # children of the parent process dead
      `pkill -INT -P #{pid}` if pid
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

require_relative 'base'
require 'open3'

module Executor
  class Shell < Base
    def execute!(*commands)
      command = commands.map do |command|
        execute_command(command)
      end.join("\n")

      retval = false

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

        stdin.close_write
        wait_thr.join
        output_thr.join; error_thr.join
        retval = wait_thr.value.success?
      end

      retval
    end

    private

    def execute_command(command)
      <<-EOF
        #{command}
        if [[ $? -ne 0 ]];
        then
          echo 'Failed to execute "#{command}"'
          exit $?
        fi
      EOF
    end
  end
end

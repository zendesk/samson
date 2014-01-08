require_relative 'base'
require 'open3'

module Executor
  class Shell < Base
    attr_reader :pid

    def execute!(*commands)
      command = commands.map do |command|
        execute_command(command)
      end.join("\n")

      if RUBY_ENGINE == 'jruby'
        command = %Q{/bin/sh -c "#{command.gsub(/"/, '\\"')}"}
      end

      stdin, stdout, stderr, @internal_thread = Bundler.with_clean_env do
        Open3.popen3(command)
      end

      @internal_thread.instance_eval do
        ActiveRecord::Base.connection_pool.release_connection
      end

      output_thr = Thread.new do
        ActiveRecord::Base.connection_pool.release_connection

        stdout.each do |line|
          @callbacks[:stdout].each {|callback| callback.call(line.chomp)}
        end
      end

      error_thr = Thread.new do
        ActiveRecord::Base.connection_pool.release_connection

        stderr.each do |line|
          @callbacks[:stderr].each {|callback| callback.call(line.chomp)}
        end
      end

      # JRuby has the possiblity of returning the internal_thread
      # without a pid attached. We're going to block until it comes
      # back so that we can kill the process TODO: may be deadlock-y
      if RUBY_ENGINE == 'jruby'
        sleep(0.1) until pid
      end

      @internal_thread.value.success?.tap do
        output_thr.join
        error_thr.join
      end
    # JRuby raises an IOError on a nonexistent first command
    rescue IOError => e
      @callbacks[:stderr].each {|callback| callback.call(error(commands.first))}
      false
    end

    def pid
      @internal_thread.try(:pid)
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
if [ "$RETVAL" != "0" ];
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

# frozen_string_literal: true

require_relative '../../test_helper'

SingleCov.covered!

describe Samson::ProcessUtils do
  describe '.ps_list' do
    it 'returns a list of running processes' do
      IO.popen("echo samson_testing; sleep 5")
      Samson::ProcessUtils.ps_list.map { |ps| ps['args'] }.must_include "sh -c echo samson_testing; sleep 5\n"
    end

    it 'skips the completed processes' do
      IO.popen("echo samson_completed")
      Samson::ProcessUtils.ps_list.map { |ps| ps['args'] }.wont_include "sh -c echo samson_completed\n"
    end
  end

  describe '.report_to_statsd' do
    it 'report the processes to statsd' do
      IO.popen("echo samson_statsd; sleep 5")
      Samson::ProcessUtils.ps_list.each do |process|
        tags = [
          "pid:#{process['pid']}",
          "ppid:#{process['ppid']}",
          "gid:#{process['gid']}",
          "pcpu:#{process['pcpu']}",
          "user:#{process['user']}",
          "start:#{process['start']}",
          "args:#{process['args']}"
        ]
        Samson.statsd.stubs(:gauge).with('process.runtime', anything, tags: tags)
      end
      Samson.statsd.stubs(:gauge).with('process.runtime', anything, anything)
      assert Samson::ProcessUtils.report_to_statsd
    end

    it 'report different value for timeout processes' do
      Samson.statsd.stubs(:gauge).with('process.runtime', anything, anything)
      Time.stubs(:parse).raises ArgumentError
      assert Samson::ProcessUtils.report_to_statsd
    end
  end
end

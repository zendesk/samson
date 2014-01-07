require_relative '../../test_helper'
require 'execution/shell'

describe Execution::Shell do
  subject do
    Execution::Shell.new.tap do |shell|
      shell.output do |line|
        stdout << line
      end

      shell.error_output do |line|
        stderr << line
      end
    end
  end

  let(:stdout) { [] }
  let(:stderr) { [] }

  describe 'stdout' do
    before do
      subject.execute!('echo "hi"', 'echo "hello"')
    end

    it 'keeps all lines' do
      stdout.must_equal(["hi\n", "hello\n"])
      stderr.must_equal([])
    end
  end

  describe 'stderr' do
    before do
      subject.execute!('echo "hi" >&2', 'echo "hello" >&2')
    end

    it 'keeps all lines' do
      stderr.must_equal(["hi\n", "hello\n"])
      stdout.must_equal([])
    end
  end

  describe 'command failures' do
    before do
      subject.execute!('ls /nonexistent/place', 'echo "hi"')
    end

    it 'does not execute the other commands' do
      stdout.must_equal(["Failed to execute \"ls /nonexistent/place\"\n"])
      stderr.wont_be_empty
    end
  end
end

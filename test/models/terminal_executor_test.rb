require_relative '../test_helper'

describe TerminalExecutor do
  let(:output) { StringIO.new }
  subject { TerminalExecutor.new(output) }

  describe '#execute_command!' do
    it 'records stdout' do
      subject.execute_command!('echo "hi"')
      subject.pid.wont_be_nil
      output.string.must_equal("hi\r\n")
    end

    it 'records stderr' do
      subject.execute_command!('echo "hi" >&2;echo "hello" >&2')
      output.string.must_equal("hi\r\nhello\r\n")
    end

    it 'stops on failure' do
      subject.execute_command!('set -e;echo "hi";false;echo "ho"')
      output.string.must_equal("hi\r\n")
    end

    it 'returns error value' do
      subject.execute_command!('set -e;blah').must_equal(false)
    end

    it 'throws exception if set -e cmd not set' do
      assert_raises Errno::ENOENT do
        subject.execute_command!('blah')
      end
    end

    it 'returns success value' do
      subject.execute_command!('echo "hi"').must_equal(true)
    end
  end

  describe '#stop!' do
    xit 'properly kills the execution' do
      thr = Thread.new(subject) do |shell|
        sleep(0.1) until shell.pid
        shell.stop!
      end

      Timeout.timeout(5) do
        begin
          subject.execute_command!('sleep 100').must_equal(false)
        rescue Interrupt
          raise "Interrupted"
        end
      end

      thr.join
    end
  end
end

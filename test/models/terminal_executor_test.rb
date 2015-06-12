require_relative '../test_helper'

describe TerminalExecutor do
  let(:output) { StringIO.new }
  subject { TerminalExecutor.new(output) }

  describe '#execute!' do
    it 'records stdout' do
      subject.execute!('echo "hi"', 'echo "hello"')
      output.string.must_equal("hi\r\nhello\r\n")
    end

    it 'records stderr' do
      subject.execute!('echo "hi" >&2', 'echo "hello" >&2')
      output.string.must_equal("hi\r\nhello\r\n")
    end

    it 'stops on failure' do
      subject.execute!('echo "hi"', 'false', 'echo "ho"')
      output.string.must_equal("hi\r\n")
    end

    it 'returns error value' do
      subject.execute!('blah').must_equal(false)
    end

    it 'returns success value' do
      subject.execute!('echo "hi"').must_equal(true)
    end

    describe 'in verbose mode' do
      subject { TerminalExecutor.new(output, verbose: true) }

      it 'records commands' do
        subject.execute!('echo "hi"', 'echo "hell o"')
        output.string.must_equal(%{» echo "hi"\r\nhi\r\n» echo "hell o"\r\nhell o\r\n})
      end

      it 'does not print subcommands' do
        subject.execute!('sh -c "echo 111"')
        output.string.must_equal("» sh -c \"echo 111\"\r\n111\r\n")
      end
    end
  end

  describe '#stop!' do
    xit 'properly kills the execution' do
      thr = Thread.new(subject) do |shell|
        sleep(0.1) until shell.pid
        shell.stop!
      end

      begin
        subject.execute!('sleep 100').must_equal(false)
      rescue Interrupt
        raise "Interrupted"
      end

      thr.join
    end
  end
end

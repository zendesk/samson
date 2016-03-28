require_relative '../test_helper'

describe TerminalExecutor do
  def with_env(env)
    old = env.map do |k, v|
      k = k.to_s
      o = ENV[k]
      ENV[k] = v
      [k, o]
    end
    yield
  ensure
    old.each { |k, v| ENV[k] = v }
  end

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

    it 'does not expose env secrets' do
      with_env MY_SECRET: 'XYZ' do
        subject.execute!('env')
        output.string.wont_include("SECRET")
      end
    end

    it "keeps CACHE_DIR" do
      with_env CACHE_DIR: 'XYZ' do
        subject.execute!('env')
        output.string.must_include("CACHE_DIR=XYZ")
      end
    end

    it "keeps custom env vars from ENV_WHITELIST" do
      with_env ENV_WHITELIST: 'ABC, XYZ,ZZZ', XYZ: 'FOO', ZZZ: 'FOO' do
        subject.execute!('env')
        output.string.must_include("XYZ=FOO")
        output.string.must_include("ZZZ=FOO")
      end
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
    def execute_and_stop(command, signal)
      thread = Thread.new(subject) do |shell|
        sleep(0.1) until shell.pgid
        shell.stop!(signal)
      end

      result = subject.execute!(command)
      thread.join
      result
    end

    it 'properly kills the execution' do
      execute_and_stop('sleep 100', 'INT').must_equal(nil)
    end

    it 'terminates hanging processes with -9' do
      execute_and_stop('trap "sleep 100" 2; sleep 100', 'KILL').must_equal(nil)
    end
  end
end

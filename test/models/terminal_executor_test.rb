# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe TerminalExecutor do
  let(:output) { StringIO.new }
  subject { TerminalExecutor.new(output, project: projects(:test)) }

  before { freeze_time }

  describe '#execute!' do
    it 'records stdout' do
      subject.execute('echo "hi"', 'echo "hello"')
      output.string.must_equal("hi\r\nhello\r\n")
    end

    it 'records stderr' do
      subject.execute('echo "hi" >&2', 'echo "hello" >&2')
      output.string.must_equal("hi\r\nhello\r\n")
    end

    it 'pretends to be a tty to show progress bars and fancy colors' do
      subject.execute('ruby -e "puts STDOUT.tty?"')
      output.string.must_equal("true\r\n")
    end

    it 'stops on failure' do
      subject.execute('echo "hi"', 'false', 'echo "ho"')
      output.string.must_equal("hi\r\n")
    end

    it 'returns error value' do
      subject.execute('blah').must_equal(false)
    end

    it 'returns success value' do
      subject.execute('echo "hi"').must_equal(true)
    end

    it 'shows a nice message when child could not be found' do
      Process.expects(:wait2).raises(Errno::ECHILD) # No child processes found
      subject.execute('blah').must_equal(false)
      out = output.string.sub(/.*blah: /, '').sub('command ', '') # linux has a different message
      out.must_equal "not found\r\nErrno::ECHILD: No child processes\n"
    end

    it 'does not expose env secrets' do
      with_env MY_SECRET: 'XYZ' do
        subject.execute('env')
        output.string.wont_include("SECRET")
      end
    end

    it "keeps CACHE_DIR" do
      with_env CACHE_DIR: 'XYZ' do
        subject.execute('env')
        output.string.must_include("CACHE_DIR=XYZ")
      end
    end

    it "removes rbenv from PATH" do
      with_env RBENV_DIR: 'XYZ', PATH: ENV["PATH"] + ":/foo/rbenv/versions/1.2.3/bin" do
        subject.execute('env')
        output.string.wont_include("RBENV_DIR")
        output.string.wont_include("/rbenv/versions")
      end
    end

    it "keeps custom env vars from ENV_WHITELIST" do
      with_env ENV_WHITELIST: 'ABC, XYZ,ZZZ', XYZ: 'FOO', ZZZ: 'FOO' do
        subject.execute('env')
        output.string.must_include("XYZ=FOO")
        output.string.must_include("ZZZ=FOO")
      end
    end

    it "preserves multibyte characters" do
      subject.execute(%(echo "#{"ß" * 400}"))
      output.string.must_equal("#{"ß" * 400}\r\n")
    end

    it "scrubs non-UTF8 characters" do
      subject.execute("echo 'K\xB7}L\xE7#\xEC'")
      output.string.must_equal "K�}L�#�\r\n"
    end

    it "ignores getpgid failures since they mean the program finished early" do
      Process.expects(:getpgid).raises(Errno::ESRCH)
      subject.execute('sleep 0.1').must_equal true
    end

    it "ignores closed output errors that happen on linux" do
      output.expects(:write).raises(Errno::EIO) # it is actually the .each call that raises it, but that is hard to stub
      subject.execute('echo "hi"').must_equal(true)
    end

    it "keeps pid while executing" do
      refute subject.pid
      refute subject.pgid

      begin
        t = Thread.new { subject.execute('sleep 0.1') }

        sleep 0.05 # wait for execution to start
        assert subject.pid
        assert subject.pgid

        sleep 0.1 # wait for execution to stop
        refute subject.pid
        refute subject.pgid
      ensure
        t.join # wait for execution to finish
      end
    end

    it "can timeout" do
      with_config :deploy_timeout, 1 do
        refute subject.execute('echo hello; sleep 10')
      end
      `ps -ef | grep "[s]leep 10"`.wont_include "sleep 10" # process got killed
      output.string.must_equal("hello\r\nTimeout: execution took longer then 1s and was terminated\n")
    end

    it "can timeout via argument" do
      refute subject.execute('echo hello; sleep 10', timeout: 1)
      `ps -ef | grep "[s]leep 10"`.wont_include "sleep 10" # process got killed
      output.string.must_equal("hello\r\nTimeout: execution took longer then 1s and was terminated\n")
    end

    it "does not log cursor movement ... special output coming from docker builds" do
      assert subject.execute("ruby -e 'puts \"Hello\\r\e[1B\\nWorld\\n\e[1K\"'")
      output.string.must_equal "Hello\rWorld\r\n\r\n"
    end

    describe "with script-executor" do
      before { RbConfig::CONFIG.expects(:[]).with("host_os").returns("darwin-foo") }

      it "uses script-executor to avoid slowness on osx" do
        PTY.expects(:spawn).with { |_, command, _| command.must_include("script-executor") }
        TerminalExecutor.any_instance.expects(:record_pid)
        subject.execute('echo "hi"')
      end

      it "works while switching directories" do
        Dir.chdir "/tmp" do
          assert subject.execute('echo "hi"')
        end
      end
    end

    it "uses regular executor on linux" do
      RbConfig::CONFIG.expects(:[]).with("host_os").returns("ubuntu")
      PTY.expects(:spawn).with { |_, command, _| command.wont_include("script-executor"); true }
      TerminalExecutor.any_instance.expects(:record_pid)
      subject.execute('echo "hi"')
    end

    describe 'in verbose mode' do
      subject { TerminalExecutor.new(output, verbose: true, project: projects(:test)) }

      before { freeze_time }

      it 'records commands' do
        subject.execute('echo "hi"', 'echo "hell o"')
        output.string.must_equal \
          %(» echo "hi"\r\nhi\r\n» echo "hell o"\r\nhell o\r\n)
      end

      it 'does not print subcommands' do
        subject.execute('sh -c "echo 111"')
        output.string.must_equal("» sh -c \"echo 111\"\r\n111\r\n")
      end

      describe 'hidden env vars' do
        it 'replaces hidden value with "HIDDEN", removes hidden prefix' do
          subject.execute('echo "export MY_VAR=hidden://some_value"')
          output.string.must_equal %(» echo "export MY_VAR=HIDDEN"\r\nexport MY_VAR=some_value\r\n)
        end
      end
    end

    describe 'with secrets' do
      def assert_resolves(id)
        secret = create_secret(id)
        subject.execute(%(echo "secret://#{id.split('/').last}"))
        output.string.must_equal "#{secret.value}\r\n"
      end

      def refute_resolves(id)
        create_secret(id)
        assert_raises Samson::Hooks::UserError do
          subject.execute(%(echo "secret://#{id.split('/').last}"))
        end
      end

      let(:deploy) { deploys(:succeeded_test) }

      it "resolves secrets" do
        assert_resolves 'global/global/global/bar'
      end

      describe "with a deploy" do
        before do
          subject.instance_variable_set(:@deploy, deploy)
          subject.instance_variable_set(:@project, deploy.project)
        end

        it "can use project specific secrets" do
          assert_resolves "global/#{deploy.project.permalink}/global/bar"
        end

        it "cannot use secret from other project" do
          refute_resolves "global/bar/global/bar"
        end

        it "can use environment specific secrets" do
          assert_resolves "#{deploy.stage.deploy_groups.first.environment.permalink}/global/global/bar"
        end

        it "cannot use secret from other environments" do
          refute_resolves "bar/global/global/bar"
        end

        it "can use deploy group specific secrets" do
          assert_resolves "global/global/#{deploy.stage.deploy_groups.first.permalink}/bar"
        end

        it "cannot use secret from other deploy group" do
          refute_resolves "global/global/bar/bar"
        end
      end

      it "fails on unresolved secrets" do
        assert_raises Samson::Hooks::UserError do
          subject.execute('echo "secret://nothing"')
        end
      end

      it "does not try to resolve secrets when none are used to avoid doing db lookups while being in a clone thread" do
        Samson::Secrets::KeyResolver.expects(:new).never
        subject.execute('echo "nothing"')
      end

      it "cannot use specific secrets without a deploy" do
        refute_resolves "global/global/#{deploy.stage.deploy_groups.first.permalink}/bar"
      end

      it "does not show secrets in verbose mode" do
        freeze_time

        subject.instance_variable_set(:@verbose, true)
        id = 'global/global/global/baz'
        secret = create_secret(id)
        subject.execute("export SECRET='secret://baz'; echo $SECRET")
        # echo prints it, but not the execution
        output.string.must_equal \
          "» export SECRET='secret://baz'; echo $SECRET\r\n#{secret.value}\r\n"
      end

      it "escapes secret value with special characters" do
        freeze_time

        id = 'global/global/global/baz'
        secret = create_secret(id, value: 'before; echo "after!"')
        # author forgot to quote the export declaration to expose the raw content of the variable
        subject.execute("export SECRET=secret://baz; echo $SECRET")
        output.string.must_equal "#{secret.value}\r\n"
      end
    end
  end

  describe '#cancel' do
    def execute_and_cancel(command, signal)
      thread = Thread.new(subject) do |shell|
        sleep(0.1) until shell.pgid
        shell.cancel(signal)
      end

      result = subject.execute(command)
      thread.join
      result
    end

    it 'properly kills the execution' do
      execute_and_cancel('sleep 100', 'INT').must_be_nil
    end

    it 'terminates hanging processes with -9' do
      execute_and_cancel('trap "sleep 100" 2; sleep 100', 'KILL').must_be_nil
    end

    it 'stops any further execution so current thread can finish' do
      subject.execute('echo 1').must_equal true
      subject.cancel 'INT'
      subject.execute('echo 1').must_equal false
    end
  end

  describe '#script_as_executable' do
    it "makes a unreadable script" do
      subject.send(:script_as_executable, "echo 1") do |path|
        File.stat(path[/\/\S+/]).mode.must_equal 0o100700
      end
    end

    it "makes project findable" do
      project = projects(:test)
      subject.instance_variable_set(:@project, project)
      subject.send(:script_as_executable, "echo 1") do |path|
        path.must_include "-#{project.permalink}-"
      end
    end

    it "makes deploy findable" do
      deploy = deploys(:succeeded_test)
      subject.instance_variable_set(:@deploy, deploy)
      subject.send(:script_as_executable, "echo 1") do |path|
        path.must_include "-#{deploy.id}-"
      end
    end

    it "cleans up the script even on error" do
      p = nil
      assert_raises RuntimeError do
        subject.send(:script_as_executable, "echo 1") do |path|
          p = path[/\/\S+/]
          assert File.exist?(p)
          raise
        end
      end
      refute File.exist?(p)
    end
  end

  describe '#verbose_command' do
    it "makes a regular command show what it executes" do
      subject.verbose_command("foo").must_equal "echo » foo\nfoo"
    end

    it "does not resolve secrets since that will be done at execution time" do
      subject.verbose_command("secret://foobar").must_equal "echo » secret://foobar\nsecret://foobar"
    end

    it "fails with verbose executor, users might leak secrets since they assume other commands are not verbose" do
      subject.instance_variable_set(:@verbose, true)
      e = assert_raises(RuntimeError) { subject.verbose_command("foo") }
      e.message.must_include "quiet"
    end
  end

  describe '#quiet' do
    it "changes verbose" do
      subject.instance_variable_set(:@verbose, true)
      was = nil
      subject.quiet { was = subject.instance_variable_get(:@verbose) }
      was.must_equal false
      subject.instance_variable_get(:@verbose).must_equal true
    end
  end
end

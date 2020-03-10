# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Samson::CommandExecutor do
  describe "#execute" do
    it "runs" do
      Samson::CommandExecutor.execute("echo", "hello", timeout: 1).must_equal(status: true, error: "", output: "hello\n")
    end

    it "captures stderr" do
      Samson::CommandExecutor.execute("sh", "-c", "echo hello 1>&2", timeout: 1).must_equal(status: true, error: "hello\n", output: "")
    end

    it "runs in specified directory" do
      Dir.mktmpdir("foobar") do |dir|
        Samson::CommandExecutor.execute("pwd", timeout: 1, dir: dir).output.must_include dir
      end
    end

    it "fails nicely on missing exectable" do
      Samson::CommandExecutor.execute("foo", "bar", timeout: 1).must_equal(status: false, error: "No such file or directory - foo", output: "")
    end

    it "does not fail on nil commands" do
      Samson::CommandExecutor.execute("echo", 1, nil, timeout: 1).must_equal(status: true, error: "", output: "1 \n")
    end

    it "shows full backtrace when failing" do
      IO.expects(:popen).raises
      e = assert_raises do
        Samson::CommandExecutor.execute("foo", timeout: 1)
      end
      e.backtrace.size.must_be :>, 10
    end

    it "times out and cleans up" do
      command = ["sleep", "15"]
      Samson::CommandExecutor.expects(:sleep) # waiting after kill ... no need to make this test slow
      time = Benchmark.realtime do
        Samson::CommandExecutor.execute(*command, timeout: 0.1).must_equal(status: false, error: "execution expired", output: "")
      end
      time.must_be :<, 0.2
      `ps -ef`.wont_include(command.join(" "))
    end

    it "does not fail when pid was already gone" do
      Process.expects(:kill).raises(Errno::ESRCH) # simulate that pid was gone and kill failed
      Samson::CommandExecutor.execute("sleep", "0.2", timeout: 0.1).must_equal(status: false, error: "execution expired", output: "")
      sleep 0.2 # do not leave process thread hanging
    end

    it "waits for zombie processes" do
      Samson::CommandExecutor.expects(:sleep) # waiting after kill ... we ignore it in this test
      Process.expects(:kill).twice # simulate that process could not be killed with :KILL
      time = Benchmark.realtime do
        Samson::CommandExecutor.execute("sleep", "0.5", timeout: 0.1).must_equal(status: false, error: "execution expired", output: "")
      end
      time.must_be :>, 0.5
    end

    it "complains about infinite timeout" do
      assert_raises ArgumentError do
        Samson::CommandExecutor.execute("sleep", "5", timeout: 0)
      end
    end

    it "does not allow injection" do
      Samson::CommandExecutor.execute("echo", "hel << lo | ;", timeout: 1).must_equal(status: true, output: "hel << lo | ;\n", error: "")
    end

    it "does not allow env access" do
      with_env FOO: 'bar' do
        Samson::CommandExecutor.execute("printenv", "FOO", timeout: 1).must_equal(status: false, error: "", output: "")
      end
    end

    it "can set env" do
      Samson::CommandExecutor.execute("printenv", "FOO", timeout: 1, env: {"FOO" => "baz"}).must_equal(status: true, error: "", output: "baz\n")
    end

    it "allows whitelisted env access" do
      with_env FOO: 'bar' do
        Samson::CommandExecutor.execute("printenv", "FOO", timeout: 1, whitelist_env: ["FOO"]).
          must_equal(status: true, error: "", output: "bar\n")
      end
    end
  end
end

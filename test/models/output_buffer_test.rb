# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe OutputBuffer do
  include OutputBufferSupport

  let(:buffer) { OutputBuffer.new }

  before { freeze_time }

  it "allows writing chunks of data to multiple listeners" do
    buffer # make sure the buffer is created before each listener

    listener1 = build_listener
    listener2 = build_listener

    wait_for_listeners(buffer, 2)

    buffer.write("hello")
    buffer.write("world")
    buffer.close

    listener1.value.must_equal ["[04:05:06] hello", "world"]
    listener2.value.must_equal ["[04:05:06] hello", "world"]
  end

  it "writes the previous content to new listeners" do
    buffer.write("hello")

    listener = build_listener

    wait_for_listeners(buffer)

    buffer.close

    listener.value.must_equal ["[04:05:06] hello"]
  end

  it "yields the buffered chunks and returns if closed" do
    buffer.write("hello")
    buffer.close

    build_listener.value.must_equal ["[04:05:06] hello"]
  end

  describe "#write" do
    it "encodes everything as utf-8 to avoid CompatibilityError" do
      listen { |o| o.write((+"Ó").force_encoding(Encoding::BINARY)) }.map(&:encoding).must_equal [Encoding::UTF_8]
    end

    it "does not inject timestamps into chunks" do
      listen { |o| 3.times { o.write("a") } }.must_equal ["[04:05:06] a", "a", "a"]
    end

    it "does not inject premature timestamps for future output" do
      listen { |o| o.write("a\n") }.must_equal ["[04:05:06] a\n"]
    end

    it "injects timestamps for multiple single-line chunks" do
      listen { |o| o.write("a"); o.write("b\n"); o.write("a"); o.write("b\n") }.
        must_equal ["[04:05:06] a", "b\n", "[04:05:06] a", "b\n"]
    end

    it "ignores empty writes" do
      listen { |o| o.write("a"); o.write(""); o.write("b") }.
        must_equal ["[04:05:06] a", "", "b"]
    end
  end

  describe "#puts" do
    it "writes a newline without argument" do
      listen(&:puts).must_equal ["[04:05:06] \n"]
    end

    # the double \n case happens randomly on travis ...
    # https://travis-ci.org/zendesk/samson/jobs/174876970
    it "writes nil as newline" do
      [["[04:05:06] \n"], ["\n", "\n"]].must_include listen { |o| o.puts nil }
    end

    it "rstrips content" do # not sure why we do this, just documenting
      listen { |o| o.puts " x " }.must_equal ["[04:05:06]  x\n"]
    end
  end

  describe "#include?" do
    before { buffer.write("hello", :message) }

    it "is true when exact message was sent" do
      assert buffer.include?(:message, "[04:05:06] hello")
    end

    it "is false when different event was sent" do
      refute buffer.include?(:close, "hello")
    end

    it "is false when different content was sent" do
      refute buffer.include?(:message, "foo")
    end
  end

  describe "#to_s" do
    before { Time.stubs(:now).returns Time.parse('2018-01-01') }

    it "serializes all messages" do
      buffer.write("hello\n", :message)
      buffer.write(nil, :close)
      buffer.write("world\n", :message)
      buffer.close
      buffer.to_s.must_equal "[00:00:00] hello\n[00:00:00] world\n"
    end

    it "does not hang when not closed" do
      buffer.write("world\n", :message)
      buffer.to_s.must_equal "[00:00:00] world\n"
    end

    it "aggregates the output into a single string" do
      ["hel", "lo", "\n", "world\n"].map { |x| buffer.write x }
      buffer.close
      buffer.to_s.must_equal "[00:00:00] hello\n[00:00:00] world\n"
    end

    it "replaces lines correctly" do
      buffer.write "hello\rworld\n"
      buffer.close
      buffer.to_s.must_equal "world\n"
    end

    it "only shows latest when message was replaced" do
      buffer.write "foo"
      buffer.write "bar\n"
      buffer.write "baz\n", :replace
      buffer.puts "baz2"
      buffer.close
      buffer.to_s.must_equal "[00:00:00] baz\n[00:00:00] baz2\n"
    end

    it "ignores other events" do
      buffer.write "hello\n"
      buffer.write "world\n", :finished
      buffer.close
      buffer.to_s.must_equal "[00:00:00] hello\n"
    end
  end

  describe "#close" do
    it "closes" do
      refute buffer.instance_variable_get(:@closed)
      buffer.close
      assert buffer.instance_variable_get(:@closed)
    end

    it "does not fail when closing multiple times by accident" do
      buffer.close
      buffer.close
    end
  end

  def build_listener
    Thread.new do
      content = []
      buffer.each { |_, chunk| content << chunk }
      content
    end
  end

  def listen
    listener = build_listener
    yield buffer
    buffer.close
    listener.value
  end
end

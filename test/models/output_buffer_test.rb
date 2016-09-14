# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe OutputBuffer do
  include OutputBufferSupport

  let(:buffer) { OutputBuffer.new }

  it "allows writing chunks of data to multiple listeners" do
    buffer # make sure the buffer is created before each listener

    listener1 = build_listener
    listener2 = build_listener

    wait_for_listeners(buffer, 2)

    buffer.write("hello")
    buffer.write("world")
    buffer.close

    listener1.value.must_equal ["hello", "world"]
    listener2.value.must_equal ["hello", "world"]
  end

  it "writes the previous content to new listeners" do
    buffer.write("hello")

    listener = build_listener

    wait_for_listeners(buffer)

    buffer.close

    listener.value.must_equal ["hello"]
  end

  it "yields the buffered chunks and returns if closed" do
    buffer.write("hello")
    buffer.close

    build_listener.value.must_equal ["hello"]
  end

  describe "#puts" do
    it "writes a newline without argument" do
      listen(&:puts).must_equal ["\n"]
    end

    it "writes nil as newline" do
      listen { |o| o.puts nil }.must_equal ["\n"]
    end

    it "rstrips content" do # not sure why we do this, just documenting
      listen { |o| o.puts " x " }.must_equal [" x\n"]
    end
  end

  describe "#include?" do
    before { buffer.write("hello", :message) }

    it "is true when exact message was sent" do
      assert buffer.include?(:message, "hello")
    end

    it "is false when different event was sent" do
      refute buffer.include?(:close, "hello")
    end

    it "is false when different content was sent" do
      refute buffer.include?(:message, "foo")
    end
  end

  describe "#to_s" do
    it "serializes all messages" do
      buffer.write("hello", :message)
      buffer.write("hello", :close)
      buffer.write("world", :message)
      buffer.to_s.must_equal "helloworld"
    end
  end

  def build_listener
    Thread.new do
      content = []
      buffer.each { |_event, chunk| content << chunk }
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

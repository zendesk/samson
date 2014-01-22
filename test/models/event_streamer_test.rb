require_relative '../test_helper'

describe EventStreamer do
  class FakeStream
    attr_reader :lines

    def initialize
      @lines = []
    end

    def write(data)
      @lines << data
    end

    def close
      @closed = true
    end

    def closed?
      @closed
    end
  end

  class FakeOutput
    def initialize(content)
      @content = content
    end

    def each(&block)
      @content.each(&block)
    end
  end

  let(:output) { FakeOutput.new([[:message, "hello\n"], [:message, "world\n"]]) }
  let(:stream) { FakeStream.new }
  let(:streamer) { EventStreamer.new(user, execution, stream) }

  let(:user) { stub(id: 1) }
  let(:execution) { stub(viewers: []) }
  let(:block) { lambda {|_, x| JSON.dump(msg: x)} }

  it "writes each message in the output into the stream" do
    streamer.start(output, &block)
    stream.lines.must_include %(event: append\ndata: {"msg":"hello\\n"}\n\n)
    stream.lines.must_include %(event: append\ndata: {"msg":"world\\n"}\n\n)
  end

  it "overwrites the previous lines if a carriage return or clear line code is present" do
    output = FakeOutput.new([[:message, "hello\rworld\n"]])
    streamer.start(output, &block)
    stream.lines.must_include %(event: append\ndata: {"msg":"hello"}\n\n)
    stream.lines.must_include %(event: replace\ndata: {"msg":"world\\n"}\n\n)
  end

  it "splits by newlines and carriage returns" do
    output = FakeOutput.new([[:message, "hel"], [:message, "lo\rwo"], [:message, "rld\n"]])
    streamer.start(output, &block)
    stream.lines.must_include %(event: append\ndata: {"msg":"hello"}\n\n)
    stream.lines.must_include %(event: replace\ndata: {"msg":"world\\n"}\n\n)
  end

  it "closes the stream when there is no more output" do
    streamer.start(output, &block)
    assert stream.closed?
  end

  it "writes a finished event" do
    streamer.start(output, &block)
    stream.lines.must_include "event: finished\ndata: \n\n"
  end

  it "adds the user to the viewers and removes after" do
    viewed = false

    streamer.start(output) do |_|
      viewed = execution.viewers.include?(user)
    end

    viewed.must_equal(true)
    execution.viewers.must_be_empty
  end
end

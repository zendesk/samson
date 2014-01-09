require 'test_helper'

describe OutputStreamer do
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

  let(:output) { FakeOutput.new(["hello", "world"]) }
  let(:stream) { FakeStream.new }
  let(:streamer) { OutputStreamer.new(stream) }

  before do
    streamer.start(output)
  end

  it "writes each message in the output into the stream" do
    stream.lines.must_include "event: output\n"
    stream.lines.must_include %(data: {"msg":"world"}\n\n)
    stream.lines.must_include %(data: {"msg":"world"}\n\n)
  end

  it "closes the stream when there is no more output" do
    assert stream.closed?
  end

  it "writes a finished event" do
    stream.lines.must_include "event: finished\n"
    stream.lines.must_include "data: \n\n"
  end
end

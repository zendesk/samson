# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: 2

describe EventStreamer do
  fake_stream = Class.new do
    attr_reader :lines

    def initialize
      @lines = []
      @buf = Queue.new
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

  fake_output = Class.new do
    def initialize(content)
      @content = content
    end

    def each(&block)
      @content.each(&block)
    end
  end

  let(:output) { fake_output.new([[:message, "hello\n"], [:message, "world\n"]]) }
  let(:stream) { fake_stream.new }
  let(:streamer) { EventStreamer.new(stream) }

  after { maxitest_kill_extra_threads } # heartbeat never finishes

  it "writes each message in the output into the stream" do
    streamer.start(output)
    stream.lines.must_include %(event: append\ndata: {"msg":"hello\\n"}\n\n)
    stream.lines.must_include %(event: append\ndata: {"msg":"world\\n"}\n\n)
  end

  it "overwrites the previous lines if a carriage return or clear line code is present" do
    output = fake_output.new([[:message, "hello\rworld\n"]])
    streamer.start(output)
    stream.lines.must_include %(event: append\ndata: {"msg":"hello"}\n\n)
    stream.lines.must_include %(event: replace\ndata: {"msg":"world\\n"}\n\n)
  end

  it "splits by newlines and carriage returns" do
    output = fake_output.new([[:message, "hel"], [:message, "lo\rwo"], [:message, "rld\n"]])
    streamer.start(output)
    stream.lines.must_include %(event: append\ndata: {"msg":"hello"}\n\n)
    stream.lines.must_include %(event: replace\ndata: {"msg":"world\\n"}\n\n)
  end

  it "closes the stream when there is no more output" do
    streamer.start(output)
    assert stream.closed?
  end
end

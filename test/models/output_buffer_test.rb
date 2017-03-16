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

    listener1.value.must_equal ["[04:05:06] hello", "[04:05:06] world"]
    listener2.value.must_equal ["[04:05:06] hello", "[04:05:06] world"]
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
      listen { |o| o.write("Ó".dup.force_encoding(Encoding::BINARY)) }.map(&:encoding).must_equal [Encoding::UTF_8]
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

  describe "#write_docker_chunk" do
    it "nicely formats complete chunk" do
      buffer.write_docker_chunk('{"foo": 1, "bar": 2}').first.must_equal("foo" => 1, "bar" => 2)
      buffer.to_s.must_equal("[04:05:06] foo: 1 | bar: 2\n")
    end

    it "ignores blank values" do
      buffer.write_docker_chunk('{"foo": " ", "bar": null}').first.must_equal("foo" => " ", "bar" => nil)
      buffer.to_s.must_equal("")
    end

    it "writes partial chunks" do # ideally piece together multiple partial chunks
      buffer.write_docker_chunk('{"foo": ').first.must_equal('message' => '{"foo":')
      buffer.to_s.must_equal "[04:05:06] {\"foo\":\n"
    end

    it "does not print spammy progressDetail" do
      buffer.write_docker_chunk('{"progressDetail": 1}').first.must_equal("progressDetail" => 1)
      buffer.to_s.must_equal ""
    end

    it "simplifies stream only responses" do
      buffer.write_docker_chunk('{"stream": 123}').first.must_equal("stream" => 123)
      buffer.to_s.must_equal("[04:05:06] 123\n")
    end

    it "coverts dockers ASCII encoding to utf-8 with valid json" do
      buffer.write_docker_chunk('{"foo": "\255"}'.dup.force_encoding(Encoding::BINARY))
      buffer.write_docker_chunk('{"bar": "meh"}')
      buffer.to_s.must_equal "[04:05:06] foo: 255\n[04:05:06] bar: meh\n"
    end

    it "coverts dockers ASCII encoding to utf-8 with invalid json" do
      buffer.write_docker_chunk('foo"\255"}'.dup.force_encoding(Encoding::BINARY))
      buffer.write_docker_chunk('---\u003e 6c9a006fd38a\n'.dup.force_encoding(Encoding::BINARY))
      buffer.write_docker_chunk('foo"\255"}')
      buffer.close

      buffer.to_s.must_equal \
        "[04:05:06] foo\"\\255\"}\n[04:05:06] ---\\u003e 6c9a006fd38a\\n\n[04:05:06] foo\"\\255\"}\n"
      build_listener.value.map(&:encoding).uniq.must_equal([Encoding::UTF_8])
      build_listener.value.map(&:valid_encoding?).uniq.must_equal([true])
    end

    it "handles multiple lines in one chunk" do
      lines = [
        { 'foo' => 1, 'bar' => 2 },
        { 'foo' => 3, 'bar' => 4 }
      ]

      output = lines.map(&:to_json).join("\n")
      buffer.write_docker_chunk(output).must_equal(lines)
      buffer.to_s.must_equal "[04:05:06] foo: 1 | bar: 2\n[04:05:06] foo: 3 | bar: 4\n"
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
    it "serializes all messages" do
      buffer.write("hello", :message)
      buffer.write("hello", :close)
      buffer.write("world", :message)
      buffer.to_s.must_equal "[04:05:06] hello[04:05:06] world"
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

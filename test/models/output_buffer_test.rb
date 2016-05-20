require_relative '../test_helper'

SingleCov.covered! uncovered: 3

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

  def build_listener
    Thread.new do
      content = []
      buffer.each { |_event, chunk| content << chunk }
      content
    end
  end
end

require_relative '../test_helper'

describe OutputBuffer do
  let(:buffer) { OutputBuffer.new }

  it "allows writing chunks of data to multiple listeners" do
    skip "There's a deadlock in here that only happens in CI"

    listener1 = build_listener
    listener2 = build_listener

    buffer.write("hello")
    buffer.write("world")
    buffer.close

    listener1.value.must_equal ["hello", "world"]
    listener2.value.must_equal ["hello", "world"]
  end

  it "writes the previous content to new listeners" do
    buffer.write("hello")

    listener = build_listener
    buffer.close

    listener.value.must_equal ["hello"]
  end

  it "yields the buffered chunks and returns if closed" do
    buffer.write("hello")
    buffer.close

    build_listener.value.must_equal ["hello"]
  end
  
  it "issues write callbacks" do
    
    issued = false
    buffer.add_write_callback do |event|
      issued = true
      assert event[1], "hello"
    end
    
    buffer.write("hello")
    
    assert issued
  end

  def build_listener
    Thread.new do
      content = []
      buffer.each {|_, chunk| content << chunk }
      content
    end
  end
end

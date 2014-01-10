require 'test_helper'

describe TerminalOutputScanner do
  let(:queue) { [] }
  let(:output) { TerminalOutputScanner.new(queue) }

  it "appends the data to the output queue" do
    output.write("foo\n")
    queue.must_equal [[:append, "foo\n"]]
  end

  it "replaces the previous line if a carriage return is encountered" do
    output.write("foo\rbar\r")
    queue.must_equal [[:append, "foo"], [:replace, "bar"]]
  end

  it "handles carriage returns followed by newlines" do
    output.write("foo\r")
    output.write("\nbar\n")
    queue.must_equal [[:append, "foo"], [:append, "\nbar\n"]]
  end

  it "keeps the remainder after a carriage return until a newline is met" do
    output.write("hello\rworld")
    output.write("!\n")
    queue.must_equal [[:append, "hello"], [:replace, "world!\n"]]
  end

  it "buffers data until either a newline or a carriage return is met" do
    output.write("foo")
    output.write("bar\n")

    queue.must_equal [[:append, "foobar\n"]]
  end
end

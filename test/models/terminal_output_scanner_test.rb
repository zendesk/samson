require 'test_helper'

describe TerminalOutputScanner do
  let(:source) { [] }
  let(:scanner) { TerminalOutputScanner.new(source) }

  def tokens
    tokens = []
    scanner.each {|token| tokens << token }
    tokens
  end

  it "appends the data to the output tokens" do
    source << "foo\n"
    tokens.must_equal [[:append, "foo\n"]]
  end

  it "replaces the previous line if a carriage return is encountered" do
    source << "foo\rbar\r"
    tokens.must_equal [[:append, "foo"], [:replace, "bar"]]
  end

  it "handles carriage returns followed by newlines" do
    source << "foo\r"
    source << "\nbar\n"
    tokens.must_equal [[:append, "foo"], [:append, "\nbar\n"]]
  end

  it "keeps the remainder after a carriage return until a newline is met" do
    source << "hello\rworld"
    source << "!\n"
    tokens.must_equal [[:append, "hello"], [:replace, "world!\n"]]
  end

  it "buffers data until either a newline or a carriage return is met" do
    source << "foo"
    source << "bar\n"

    tokens.must_equal [[:append, "foobar\n"]]
  end
end

# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe TerminalOutputScanner do
  let(:source) { [] }
  let(:scanner) { TerminalOutputScanner.new(source) }

  def tokens
    tokens = []
    scanner.each { |token| tokens << token }
    tokens
  end

  def output(str)
    source << [:message, str]
  end

  it "appends the data to the output tokens" do
    output("foo\n")
    tokens.must_equal [[:append, "foo\n"]]
  end

  it "replaces the previous line if a carriage return is encountered" do
    output("foo\rbar\r")
    tokens.must_equal [[:append, "foo"], [:replace, "bar"]]
  end

  it "handles carriage returns followed by newlines" do
    output("foo\r")
    output("\nbar\n")
    tokens.must_equal [[:append, "foo"], [:append, "\nbar\n"]]
  end

  it "keeps the remainder after a carriage return until a newline is met" do
    output("hello\rworld")
    output("!\n")
    tokens.must_equal [[:append, "hello"], [:replace, "world!\n"]]
  end

  it "buffers data until either a newline or a carriage return is met" do
    output("foo")
    output("bar\n")
    tokens.must_equal [[:append, "foobar\n"]]
  end

  it "behaves well with carriage return + newlines" do
    output("foo\r\n")
    tokens.must_equal [[:append, "foo\n"]]
  end

  it 'can handle an invalid UTF-8 character' do
    output("invalid char\255\n")
    tokens.must_equal [[:append, "invalid char�\n"]]
  end

  it "returns finished event" do
    source << [:finished, "foo"]
    tokens.must_equal [[:finished, "foo"]]
  end
end

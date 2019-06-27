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

  describe "#to_s" do
    let(:source) { OutputBuffer.new }
    let(:string) { TerminalOutputScanner.new(source).to_s }

    before { Time.stubs(:now).returns Time.parse('2018-01-01') }

    it "fails when output is still open and would hang forever" do
      assert_raises(RuntimeError) { string }
    end

    it "aggregates the output into a single string" do
      ["hel", "lo", "\n", "world\n"].map { |x| source.write x }
      source.close
      string.must_equal "[00:00:00] hello\n[00:00:00] world\n"
    end

    it "replaces lines correctly" do
      source.write "hello\rworld\n"
      source.close
      string.must_equal "world\n"
    end

    it "only shows latest when message was replaced" do
      source.write "foo"
      source.write "bar\n"
      source.write "baz\n", :replace
      source.puts "baz2"
      source.close
      string.must_equal "[00:00:00] baz\n[00:00:00] baz2\n"
    end

    it "ignores other events" do
      source.write "hello\n"
      source.write "world\n", :finished
      source.close
      string.must_equal "[00:00:00] hello\n"
    end
  end
end

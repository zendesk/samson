# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Samson::ExtraDig do
  describe "#dig_fetch" do
    it "fetches existing" do
      {a: {b: 1}}.dig_fetch(:a, :b).must_equal 1
    end

    it "fetches shallow" do
      {a: {b: 1}}.dig_fetch(:a).must_equal b: 1
    end

    it "fetches nil" do
      {a: {b: nil}}.dig_fetch(:a, :b).must_be_nil
    end

    it "fetches with full key when missing" do
      e = assert_raises(KeyError) { {a: {b: 1}}.dig_fetch(:a, :c) }
      e.message.must_equal "key not found: [:a, :c]"
      e.key.must_equal [:a, :c]
      e.receiver.must_equal a: {b: 1}
    end

    it "returns default when missing" do
      {a: {b: 1}}.dig_fetch(:a, :c) { 123 }.must_equal 123
    end

    describe "#dig_set" do
      let(:subject) { {a: {b: 1}} }

      it "sets shallow" do
        subject.dig_set([:a], 2)
        subject.must_equal a: 2
      end

      it "sets nested" do
        subject.dig_set([:a, :b], 2)
        subject.must_equal a: {b: 2}
      end

      it "does not set missing since we do not know if things are arrays or hashes" do
        e = assert_raises(KeyError) { subject.dig_set([:b, :c], 2) }
        e.message.must_equal "key not found: [:b]"
        e.key.must_equal [:b]
        e.receiver.must_equal subject
      end

      it "fail without value" do
        assert_raises(ArgumentError) { subject.dig_set([:a]) }
      end

      it "fail without keys" do
        e = assert_raises(ArgumentError) { subject.dig_set([], 1) }
        e.message.must_equal "No key given"
      end
    end
  end
end

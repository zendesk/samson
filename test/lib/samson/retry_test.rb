# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Samson::Retry do
  describe ".retry_when_not_unique" do
    it "retries when not unique" do
      calls = 0
      assert_raises ActiveRecord::RecordNotUnique do
        Samson::Retry.retry_when_not_unique do
          calls += 1
          raise ActiveRecord::RecordNotUnique
        end
      end

      calls.must_equal 2
    end

    it "does not retry on other errors" do
      calls = 0
      assert_raises RuntimeError do
        Samson::Retry.retry_when_not_unique do
          calls += 1
          raise "Nope"
        end
      end

      calls.must_equal 1
    end
  end

  describe ".with_retries" do
    it "retries when check passes" do
      calls = 0
      assert_raises RuntimeError do
        Samson::Retry.with_retries([RuntimeError], 3, only_if: ->(_) { true }) do
          calls += 1
          raise "Nope"
        end
      end

      calls.must_equal 4
    end

    it "sleeps before retrying when requested" do
      Samson::Retry.expects(:sleep).times(3)
      assert_raises RuntimeError do
        Samson::Retry.with_retries([RuntimeError], 3, wait_time: 1) do
          raise "Nope"
        end
      end
    end

    it "does not retry when check fails" do
      calls = 0
      assert_raises RuntimeError do
        Samson::Retry.with_retries([RuntimeError], 3, only_if: ->(_) { false }) do
          calls += 1
          raise "Nope"
        end
      end

      calls.must_equal 1
    end
  end

  describe ".until_result" do
    it "returns result" do
      calls = 0
      Samson::Retry.until_result(tries: 3, wait_time: 1, error: "Ops") do
        calls += 1
        :x
      end.must_equal :x
      calls.must_equal 1
    end

    it "retries when result is not returned" do
      results = [nil, nil, :x]
      calls = 0
      Samson::Retry.expects(:sleep).times(2)
      Samson::Retry.until_result(tries: 3, wait_time: 1, error: "Ops") do
        calls += 1
        results.shift
      end.must_equal :x
      calls.must_equal 3
    end

    it "raises when it runs out of tries" do
      results = [nil, nil, nil, :x]
      calls = 0
      Samson::Retry.expects(:sleep).times(2)
      assert_raises RuntimeError do
        Samson::Retry.until_result(tries: 3, wait_time: 1, error: "Ops") do
          calls += 1
          results.shift
        end
      end
      calls.must_equal 3
    end

    it "returns nil when it runs out of tries and no error was set" do
      results = [nil, nil, nil, :x]
      calls = 0
      Samson::Retry.expects(:sleep).times(2)
      Samson::Retry.until_result(tries: 3, wait_time: 1, error: nil) do
        calls += 1
        results.shift
      end.must_be_nil
      calls.must_equal 3
    end
  end
end

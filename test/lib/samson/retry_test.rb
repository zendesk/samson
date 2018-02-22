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
end

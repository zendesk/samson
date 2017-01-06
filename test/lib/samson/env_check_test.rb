# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Samson::EnvCheck do
  describe '.set?' do
    {
      '1' => true,
      '0' => false,
      nil => false,
      'true' => true,
      'false' => false,
      '' => false
    }.each do |value, expected|
      it "is #{expected} when set to #{value}" do
        with_env('TEST_VALUE' => value) do
          Samson::EnvCheck.set?('TEST_VALUE').must_equal expected
        end
      end
    end
  end
end

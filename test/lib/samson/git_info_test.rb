# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Samson::GitInfo do
  describe ".version" do
    before { Samson::GitInfo.instance_variable_set(:@version, nil) }

    it "works" do
      Samson::GitInfo.version.to_s.must_match /^\d+(\.\d+){2,3}$/
    end

    it "fails when command fails" do
      `fill-$?-with-a-failure 2>&1`
      Samson::GitInfo.expects(:`).returns("")
      assert_raises { Samson::GitInfo.version }
    end
  end
end

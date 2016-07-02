require_relative '../../../test_helper'

SingleCov.covered!

describe Api::V1::ApplicationController do
  it "uses :basic warden strategy" do
    assert_equal([:basic], @controller.warden_strategies)
  end
end

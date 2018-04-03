# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Deploy do
  let(:deploy) { deploys(:succeeded_test) }

  describe "#environment_variables" do
    it "can use environment variables" do
      deploy.environment_variables << EnvironmentVariable.create(
        name: "ENV_VARIABLE_ONE",
        value: "ONE"
      )
      deploy.environment_variables.count.must_equal 1
    end
  end
end

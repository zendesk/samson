# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe DeployGroup do
  it "has scoped_environment_variables" do
    deploy_groups(:pod100).scoped_environment_variables.must_equal []
  end
end

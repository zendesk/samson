# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered!

describe AcceptsEnvironmentVariables do
  it "adds environment_variables" do
    EnvironmentVariableGroup.new.environment_variables.must_equal []
  end

  it "accepts attributes for environment_variables" do
    group = EnvironmentVariableGroup.new(environment_variables_attributes: {0 => {name: 'X'}})
    group.environment_variables.map(&:name).must_equal ['X']
  end

  it "does not accept attributes for environment_variables without name" do
    group = EnvironmentVariableGroup.new(environment_variables_attributes: {0 => {name: ''}})
    group.environment_variables.map(&:name).must_equal []
  end
end

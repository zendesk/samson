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

  describe "#validate_unique_environment_variables" do
    let(:group) do
      EnvironmentVariableGroup.new(name: 'foo', environment_variables_attributes: {0 => {name: 'foo', value: 'bar'}})
    end

    it "is valid with unique env vars" do
      assert_valid group
    end

    it "is invalid with duplicate environment_variables" do
      group.environment_variables.build(name: 'foo', value: 'bar2')
      refute_valid group
      group.errors.full_messages.must_equal ["Non-Unique environment variables found for: foo"]
    end

    it "does not check when environment_variables were not changed" do
      group.save!
      group.reload
      assert_sql_queries(0) { assert_valid group }
    end
  end
end

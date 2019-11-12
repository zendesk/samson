# frozen_string_literal: true
require_relative "../test_helper"

SingleCov.covered!

describe EnvironmentVariableGroupOwner do
  let(:group) do
    EnvironmentVariableGroup.create!(
      name: "Foo"
    )
  end
  let(:owner) { EnvironmentVariableGroupOwner.new(name: "xyz", environment_variable_group: group) }

  describe "validations" do
    it "is valid" do
      assert_valid owner
    end

    it "is not valid" do
      owner.name = nil
      refute_valid owner
    end
  end
end

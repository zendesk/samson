# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered!

describe GroupScope do
  let(:deploy_group) { deploy_groups(:pod100) }
  let(:environment) { deploy_group.environment }
  let(:project) { projects(:test) }
  let(:deploy_group_scope_type_and_id) { "DeployGroup-#{deploy_group.id}" }
  let(:environment_variable) { EnvironmentVariable.new(name: "NAME", parent: project) } # TODO: don't use a plugin model

  describe "#scope_type_and_id=" do
    it "splits type and id" do
      environment_variable.scope_type_and_id = deploy_group_scope_type_and_id
      environment_variable.scope.must_equal deploy_group
      assert_valid environment_variable
    end

    it "is invalid with wrong type" do
      environment_variable.scope_type_and_id = "Stage-#{project.id}"
      refute_valid environment_variable
    end
  end

  describe "#scope_type_and_id" do
    it "builds from scope" do
      environment_variable.scope = deploy_group
      environment_variable.scope_type_and_id.must_equal deploy_group_scope_type_and_id
    end

    it "builds from nil so it is matched in rendered selects" do
      environment_variable.scope_type_and_id.must_be_nil
    end
  end
end

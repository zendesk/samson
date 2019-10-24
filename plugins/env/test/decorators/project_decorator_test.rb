# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Project do
  let(:project) { projects(:test) }
  let(:group) { EnvironmentVariableGroup.create!(name: "Foo", environment_variables_attributes: [env_attributes]) }
  let(:env_attributes) { {name: "A", value: "B", scope_type_and_id: "Environment-#{environments(:production)}"} }

  describe "auditing" do
    it "does not audit when var did not change" do
      project.update_attributes!(name: 'Bar')
      project.audits.map(&:audited_changes).must_equal([{'name' => ['Foo', 'Bar']}])
    end

    it "records when only env vars change" do
      project.update_attributes!(environment_variables_attributes: [env_attributes])
      project.audits.map(&:audited_changes).must_equal(
        [{"environment_variables" => ["", "A=\"B\" # All"]}]
      )
    end

    it "records when env groups change" do
      project.update_attributes!(environment_variable_group_ids: [group.id])
      project.audits.map(&:audited_changes).must_equal(
        [{"environment_variables" => ["", "A=\"B\" # All"]}]
      )
    end

    it "records when env vars of env group change" do
      group.projects << project
      var = group.environment_variables.first!
      group.update_attributes!(environment_variables_attributes: [env_attributes.merge(id: var.id, value: "NEW")])
      project.audits.map(&:audited_changes).must_equal(
        [{"environment_variables" => ["A=\"B\" # All", "A=\"NEW\" # All"]}]
      )
    end

    it "records when env vars and other attributes changed" do
      project.update_attributes!(
        name: 'Bar',
        environment_variables_attributes: [env_attributes]
      )
      project.audits.map(&:audited_changes).must_equal(
        [{'name' => ['Foo', 'Bar'], "environment_variables" => ["", "A=\"B\" # All"]}]
      )
    end

    it "does not records when existing vars did not change" do
      existing = project.environment_variables.create!(env_attributes)
      project.update_attributes!(
        environment_variables_attributes: [env_attributes.merge(id: existing.id)]
      )
      refute project.audits.last
    end
  end

  describe "nested_environment_variables" do
    let(:group_env) { project.environment_variable_groups.flat_map(&:environment_variables) }

    before do
      @project_env = EnvironmentVariable.create!(parent: project, name: 'B', value: 'b')
      ProjectEnvironmentVariableGroup.create!(environment_variable_group: group, project: project)
    end

    it "includes only project specific environment variables" do
      project.nested_environment_variables(project_specific: true).
      must_equal [@project_env]
    end

    it "includes only project groups environment variables" do
      project.nested_environment_variables(project_specific: false).
      must_equal group_env
    end

    it "includes both project and groups environment variables" do
      project.nested_environment_variables.
      must_equal group_env.unshift(@project_env)
    end
  end
end

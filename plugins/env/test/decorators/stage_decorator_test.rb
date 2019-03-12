# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Stage do
  let(:stage) { stages(:test_staging) }
  let(:project) { stage.project }
  let(:env_attributes) { {0 => {name: "A", value: "B"}} }

  it "has scoped_environment_variables" do
    stage.scoped_environment_variables.must_equal []
  end

  describe "accept nested scoped_environment_variables" do
    def create_scoped_environment_variable
      stage.update_attributes!(scoped_environment_variables_attributes: env_attributes)
    end

    it "create scoped environment variables" do
      assert_difference "stage.scoped_environment_variables.count", +1 do
        create_scoped_environment_variable
      end
    end

    it "updates old environment variable" do
      create_scoped_environment_variable
      assert_difference "stage.scoped_environment_variables.count", 0 do
        env_attributes.values.first[:id] = stage.scoped_environment_variables.first.id
        stage.update_attributes!(
          scoped_environment_variables_attributes: env_attributes
        )
      end
    end

    it "invalid without parent scope" do
      stage.scoped_environment_variables.build(name: "A1", value: "B1")
      refute_valid stage
      stage.errors.full_messages.must_equal ["Scoped environment variables parent must exist"]
    end

    it "update parent scope with nested attributes" do
      create_scoped_environment_variable
      env_variable = stage.scoped_environment_variables.first
      env_variable.parent_id.must_equal project.id
      env_variable.parent_type.must_equal 'Project'
    end

    it "does not audit when var change" do
      stage.update_attributes!(
        name: 'Bar',
        scoped_environment_variables_attributes: env_attributes
      )
      stage.audits.map(&:audited_changes).must_equal([{'name' => ['Staging', 'Bar']}])
    end
  end

  describe "#validate_unique_scoped_environment_variables" do
    let(:stage_env) do
      stage.assign_attributes(scoped_environment_variables_attributes: env_attributes)
      stage
    end

    it "is valid with unique env vars" do
      assert_valid stage_env
    end

    it "is invalid with duplicate environment_variables" do
      stage_env.scoped_environment_variables.build(
        name: "A", value: "A1", parent_id: project.id, parent_type: 'Project'
      )
      refute_valid stage_env
      stage_env.errors.full_messages.must_equal ["Non-Unique environment variables found for: A"]
    end
  end
end

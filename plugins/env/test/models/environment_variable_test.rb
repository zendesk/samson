require_relative "../test_helper"

SingleCov.covered! uncovered: 7

describe EnvironmentVariable do
  let(:project) { stage.project }
  let(:stage) { stages(:test_staging) }
  let(:deploy_group) { stage.deploy_groups.first }
  let(:environment) { deploy_group.environment }
  let(:deploy_group_scope_type_and_id) { "DeployGroup-#{deploy_group.id}" }
  let(:environment_variable) { EnvironmentVariable.new(name: "NAME") }

  describe ".env" do
    before do
      EnvironmentVariableGroup.create!(
        environment_variables_attributes: {
          0 => {name: "X", value: "Y"},
          2 => {name: "Z", value: "A", scope: deploy_group}
        },
        name: "G1"
      )
      EnvironmentVariableGroup.create!(
        environment_variables_attributes: {
          1 => {name: "Y", value: "Z"}
        },
        name: "G2"
      )
    end

    it "is empty for nothing" do
      EnvironmentVariable.env(Project.new, nil).must_equal({})
      EnvironmentVariable.env(Project.new, 123).must_equal({})
    end

    describe "with an assigned group and variables" do
      before do
        project.environment_variable_groups = EnvironmentVariableGroup.all
        project.environment_variables.create!(name: "PROJECT", value: "DEPLOY", scope: deploy_group)
        project.environment_variables.create!(name: "PROJECT", value: "PROJECT")
      end

      it "includes only common for common groups" do
        EnvironmentVariable.env(project, nil).must_equal("X" => "Y", "Y" => "Z", "PROJECT" => "PROJECT")
      end

      it "includes common for scoped groups" do
        EnvironmentVariable.env(project, deploy_group).must_equal(
          "PROJECT" => "DEPLOY", "X" => "Y", "Z" => "A", "Y" => "Z"
        )
      end

      it "overwrites environment groups with project variables" do
        project.environment_variables.create!(name: "X", value: "OVER")
        EnvironmentVariable.env(project, nil).must_equal("X" => "OVER", "Y" => "Z", "PROJECT" => "PROJECT")
      end

      it "keeps correct order for different priorities" do
        project.environment_variables.create!(name: "PROJECT", value: "ENV", scope: environment)

        project.environment_variables.create!(name: "X", value: "ALL")
        project.environment_variables.create!(name: "X", value: "ENV", scope: environment)
        project.environment_variables.create!(name: "X", value: "GROUP", scope: deploy_group)

        project.environment_variables.create!(name: "Y", value: "ENV", scope: environment)
        project.environment_variables.create!(name: "Y", value: "ALL")

        EnvironmentVariable.env(project, deploy_group).must_equal(
          "X" => "GROUP", "Y" => "ENV", "PROJECT" => "DEPLOY", "Z" => "A"
        )
      end

      it "produces few queries when doing multiple versions as the env builder does" do
        groups = DeployGroup.all.to_a
        assert_sql_queries 2 do
          EnvironmentVariable.env(project, nil)
          groups.each { |deploy_group| EnvironmentVariable.env(project, deploy_group) }
        end
      end

      it "can resolve references" do
        project.environment_variables.last.update_column(:value, "PROJECT--$POD_ID--$POD_ID_NOT--${POD_ID}")
        project.environment_variables.create!(name: "POD_ID", value: "1")
        EnvironmentVariable.env(project, nil).must_equal(
          "PROJECT" => "PROJECT--1--$POD_ID_NOT--1", "POD_ID" => "1", "X" => "Y", "Y" => "Z"
        )
      end
    end
  end

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
      environment_variable.scope_type_and_id.must_equal nil
    end
  end
end

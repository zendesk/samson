require_relative "../test_helper"

describe EnvironmentVariable do
  let(:stage) { stages(:test_staging) }
  let(:deploy_group) { stage.deploy_groups.first }

  describe ".env" do
    before do
      EnvironmentVariableGroup.create!(
        environment_variables_attributes: {
          0 => {name: "X", value: "Y"},
          2 => {name: "Z", value: "A", deploy_group: deploy_group}
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
      EnvironmentVariable.env(Stage.new, nil).must_equal({})
      EnvironmentVariable.env(Stage.new, 123).must_equal({})
    end

    describe "with an assigned group and variables" do
      before do
        stage.environment_variable_groups = EnvironmentVariableGroup.all
        stage.environment_variables.create!(name: "STAGE", value: "DEPLOY", deploy_group: deploy_group)
        stage.environment_variables.create!(name: "STAGE", value: "STAGE")
      end

      it "includes only common for common groups" do
        EnvironmentVariable.env(stage, nil).must_equal("X"=>"Y", "Y" => "Z", "STAGE" => "STAGE")
      end

      it "includes common for scoped groups" do
        EnvironmentVariable.env(stage, deploy_group.id).must_equal("STAGE"=>"DEPLOY", "X"=>"Y", "Z"=>"A", "Y"=>"Z")
      end

      it "overwrites environment groups" do
        stage.environment_variables.create!(name: "X", value: "OVER")
        EnvironmentVariable.env(stage, nil).must_equal("X"=>"OVER", "Y" => "Z", "STAGE" => "STAGE")
      end

      it "produces few queries when doing multiple versions as the env builder does" do
        groups = DeployGroup.all.to_a
        assert_sql_queries 2 do
          EnvironmentVariable.env(stage, nil)
          groups.each { |deploy_group| EnvironmentVariable.env(stage, deploy_group.id) }
        end
      end

      it "can resolve references" do
        stage.environment_variables.last.update_column(:value, "STAGE--$POD_ID--$POD_ID_NOT--${POD_ID}")
        stage.environment_variables.create!(name: "POD_ID", value: "1")
        EnvironmentVariable.env(stage, nil).must_equal("STAGE"=>"STAGE--1--$POD_ID_NOT--1", "POD_ID"=>"1", "X"=>"Y", "Y"=>"Z")
      end
    end
  end
end

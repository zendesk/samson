# frozen_string_literal: true
require_relative "../test_helper"

SingleCov.covered!

describe EnvironmentVariableGroup do
  describe "auditing" do
    let(:env_attributes) { {name: "A", value: "B", scope_type_and_id: "Environment-#{environments(:production)}"} }
    let(:project) { projects(:test) }
    let(:group) do
      EnvironmentVariableGroup.create!(
        name: "Foo",
        environment_variables_attributes: [env_attributes],
        projects: [project]
      )
    end
    let(:var) { group.environment_variables.first! }

    it "does not record an audit when env vars did not change" do
      group.update!(environment_variables_attributes: [env_attributes.merge(id: var.id)])
      project.audits.map(&:audited_changes).must_equal [
        {"environment_variables" => ["", "A=\"B\" # All"]},
      ]
    end

    it "record an audit on all projects when env vars did change" do
      group.update!(environment_variables_attributes: [env_attributes.merge(id: var.id, value: 'NEW')])
      project.audits.map(&:audited_changes).must_equal(
        [
          {"environment_variables" => ["", "A=\"B\" # All"]},
          {"environment_variables" => ["A=\"B\" # All", "A=\"NEW\" # All"]}
        ]
      )
    end

    describe "#as_json" do
      it "includes variable names" do
        group.as_json.fetch("variable_names").must_equal ["A"]
      end
    end

    describe "#variable_names" do
      it "gives unique variable names" do
        group.update!(
          environment_variables_attributes: [
            {name: "B", value: "B", scope_type_and_id: "Environment-#{environments(:production)}"},
            {name: "C", value: "C", scope_type_and_id: "Environment-#{environments(:production)}"},
          ]
        )
        group.variable_names.must_equal ["A", "B", "C"]
      end
    end
  end

  describe "#validate_external_url_valid" do
    with_env EXTERNAL_ENV_GROUP_S3_REGION: "us-east-1", EXTERNAL_ENV_GROUP_S3_BUCKET: "a-bucket"

    let(:group) { EnvironmentVariableGroup.new(name: "Foo", external_url: "https://a-bucket.s3.amazonaws.com/foo") }

    it "is valid when correct" do
      ExternalEnvironmentVariableGroup.any_instance.expects(:read).returns(true)
      assert_valid group
    end

    it "is invalid when incorrect" do
      ExternalEnvironmentVariableGroup.any_instance.expects(:read).raises("Foo")
      refute_valid group
      group.errors[:external_url].must_equal ["Url Invalid: Foo"]
    end
  end
end

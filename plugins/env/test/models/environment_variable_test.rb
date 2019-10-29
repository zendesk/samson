# frozen_string_literal: true
require_relative "../test_helper"

SingleCov.covered!

describe EnvironmentVariable do
  let(:project) { stage.project }
  let(:stage) { stages(:test_staging) }
  let(:deploy) { Deploy.new(project: project) }
  let(:deploy_group) { stage.deploy_groups.first }
  let(:environment) { deploy_group.environment }
  let(:deploy_group_scope_type_and_id) { "DeployGroup-#{deploy_group.id}" }
  let(:environment_variable) { EnvironmentVariable.new(name: "NAME", parent: project, value: "foo") }

  describe "validations" do
    # postgres and sqlite do not have string limits defined
    if ActiveRecord::Base.connection.class.name == "ActiveRecord::ConnectionAdapters::Mysql2Adapter"
      it "validates value length" do
        environment_variable.value = "a" * 1_000_000
        refute_valid environment_variable
      end
    end
  end

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
      EnvironmentVariable.env(Deploy.new(project: Project.new), nil).must_equal({})
      EnvironmentVariable.env(Deploy.new(project: Project.new), 123).must_equal({})
    end

    describe "env vars from GitHub" do
      with_env DEPLOYMENT_ENV_REPO: "organization/repo_name"

      before do
        project.use_env_repo = true
      end

      it "returns a processed env hash" do
        stub_github_api(
          "repos/organization/repo_name/contents/generated/foo/pod100.env",
          "FROM_REPO_VAR_ONE=one\nVAR_TWO=two\n"
        )
        expected_result = {"FROM_REPO_VAR_ONE" => "one", "VAR_TWO" => "two"}
        EnvironmentVariable.env(deploy, deploy_group).must_equal expected_result
      end

      it "ignores without deploy group" do
        EnvironmentVariable.env(deploy, nil).must_equal({})
      end

      it "merges repo env into db env" do
        project.environment_variable_groups = EnvironmentVariableGroup.all
        project.environment_variables.create!(name: "PROJECT", value: "PROJECT")
        stub_github_api(
          "repos/organization/repo_name/contents/generated/foo/pod100.env",
          "FROM_REPO_VAR_ONE=one\nVAR_TWO=two\n"
        )
        expected_result = {
          "FROM_REPO_VAR_ONE" => "one", "VAR_TWO" => "two",
          "PROJECT" => "PROJECT", "Z" => "A", "X" => "Y", "Y" => "Z"
        }
        EnvironmentVariable.env(deploy, deploy_group).must_equal expected_result
      end

      it "returns the env first deploy env then db env then repo env" do
        project.environment_variable_groups = EnvironmentVariableGroup.all
        project.environment_variables.create!(name: "PROJECT", value: "DEPLOY", scope: deploy_group)
        project.environment_variables.create!(name: "PROJECT", value: "PROJECT")
        project.environment_variables.create!(name: "VAR_TWO", value: "db_two")
        stub_github_api(
          "repos/organization/repo_name/contents/generated/foo/pod100.env",
          "FROM_REPO_VAR_ONE=one\nVAR_TWO=two\nPROJECT=NOT_PROJECT"
        )
        expected_result = {
          "FROM_REPO_VAR_ONE" => "one", "VAR_TWO" => "db_two",
          "PROJECT" => "DEPLOY", "Z" => "A", "X" => "Y", "Y" => "Z"
        }
        EnvironmentVariable.env(deploy, deploy_group).must_equal expected_result
      end

      it "shows error when repo env file does not exist" do
        stub_github_api("repos/organization/repo_name/contents/generated/foo/pod100.env", "No content", 404)
        assert_raises(Samson::Hooks::UserError) do
          EnvironmentVariable.env(deploy, deploy_group)
        end
      end

      it "does not read env vars from repo when project is not opted in" do
        project.use_env_repo = false
        stub_github_api(
          "repos/organization/repo_name/contents/generated/foo/pod100.env",
          "VAR_THREE=three\nVAR_FOUR=four\n"
        )
        expected_result = {"VAR_THREE" => "three", "VAR_FOUR" => "four"}
        EnvironmentVariable.env(deploy, deploy_group).wont_equal expected_result
      end
    end

    describe "env vars from config service" do
      def fake_response(response)
        stub(body: stub(read: response))
      end

      with_env CONFIG_SERVICE_REGION: "us-east-1",
        CONFIG_SERVICE_BUCKET: "a-bucket",
        CONFIG_SERVICE_DR_REGION: "ap-southeast-2",
        CONFIG_SERVICE_DR_BUCKET: "dr-bucket"
      let(:s3) { stub("S3") }

      before do
        project.config_service = true
        EnvironmentVariable.instance_variable_set(:@config_service_s3_client, nil) # clear cache
        Aws::S3::Client.stubs(:new).returns(s3)
      end

      it "add to env hash" do
        response = {"FOO" => "one"}.to_yaml
        s3.expects(:get_object).with(bucket: 'a-bucket', key: 'samson/foo/pod100.yml').returns(fake_response(response))
        EnvironmentVariable.env(deploy, deploy_group).must_equal "FOO" => "one"
      end

      it "ignores without deploy group" do
        EnvironmentVariable.env(deploy, nil).must_equal({})
      end

      it "shows error when deploy group is not configured" do
        s3.expects(:get_object).raises(Aws::S3::Errors::NoSuchKey.new({}, "The specified key does not exist."))
        e = assert_raises(Samson::Hooks::UserError) { EnvironmentVariable.env(deploy, deploy_group) }
        e.message.must_equal(
          "Error reading env vars from config service: key \"samson/foo/pod100.yml\" does not exist in bucket a-bucket!"
        )
      end

      it "tries reading from a DR bucket if available" do
        response = {"FOO" => "one"}.to_yaml
        s3.expects(:get_object).with(
          bucket: 'a-bucket', key: 'samson/foo/pod100.yml'
        ).raises(Aws::S3::Errors::ServiceError.new({}, "DOWN"))
        s3.expects(:get_object).with(
          bucket: 'dr-bucket', key: 'samson/foo/pod100.yml'
        ).returns(fake_response(response))
        EnvironmentVariable.env(deploy, deploy_group).must_equal "FOO" => "one"
      end

      it "shows error when api times out after multiple retries" do
        s3.expects(:get_object).times(8).raises(Aws::S3::Errors::ServiceError.new({}, "DOWN"))
        e = assert_raises(Samson::Hooks::UserError) { EnvironmentVariable.env(deploy, deploy_group) }
        e.message.must_equal "Error reading env vars from config service: DOWN"
      end

      it "refuses to deploy when configured but env var is missing" do
        with_env CONFIG_SERVICE_BUCKET: nil do
          assert_raises Samson::Hooks::UserError do
            EnvironmentVariable.env(deploy, deploy_group)
          end
        end
      end

      it "does not read env vars when project is not opted in" do
        project.config_service = false
        EnvironmentVariable.env(deploy, deploy_group)
      end
    end

    describe "with an assigned group and variables" do
      before do
        project.environment_variable_groups = EnvironmentVariableGroup.all
        project.environment_variables.create!(name: "PROJECT", value: "DEPLOY", scope: deploy_group)
        project.environment_variables.create!(name: "PROJECT", value: "PROJECT")
      end

      it "includes only common for common groups" do
        EnvironmentVariable.env(deploy, nil).must_equal("X" => "Y", "Y" => "Z", "PROJECT" => "PROJECT")
      end

      it "includes common for scoped groups" do
        EnvironmentVariable.env(deploy, deploy_group).must_equal(
          "PROJECT" => "DEPLOY", "X" => "Y", "Z" => "A", "Y" => "Z"
        )
      end

      it "overwrites environment groups with project variables" do
        project.environment_variables.create!(name: "X", value: "OVER")
        EnvironmentVariable.env(deploy, nil).must_equal("X" => "OVER", "Y" => "Z", "PROJECT" => "PROJECT")
      end

      it "keeps correct order for different priorities" do
        project.environment_variables.create!(name: "PROJECT", value: "ENV", scope: environment)

        project.environment_variables.create!(name: "X", value: "ALL")
        project.environment_variables.create!(name: "X", value: "ENV", scope: environment)
        project.environment_variables.create!(name: "X", value: "GROUP", scope: deploy_group)

        project.environment_variables.create!(name: "Y", value: "ENV", scope: environment)
        project.environment_variables.create!(name: "Y", value: "ALL")

        EnvironmentVariable.env(deploy, deploy_group).must_equal(
          "X" => "GROUP", "Y" => "ENV", "PROJECT" => "DEPLOY", "Z" => "A"
        )
      end

      it "produces few queries when doing multiple versions as the env builder does" do
        groups = DeployGroup.all.to_a
        assert_sql_queries 2 do
          EnvironmentVariable.env(deploy, nil)
          groups.each { |deploy_group| EnvironmentVariable.env(deploy, deploy_group) }
        end
      end

      it "can resolve references" do
        project.environment_variables.last.update_column(:value, "PROJECT--$POD_ID--$POD_ID_NOT--${POD_ID}")
        project.environment_variables.create!(name: "POD_ID", value: "1")
        EnvironmentVariable.env(deploy, nil).must_equal(
          "PROJECT" => "PROJECT--1--$POD_ID_NOT--1", "POD_ID" => "1", "X" => "Y", "Y" => "Z"
        )
      end

      it "can does not cache resolved references" do
        project.environment_variables.last.update_column(:value, "PROJECT--$POD_ID")
        project.environment_variables.create!(name: "POD_ID", value: "1", scope: deploy_groups(:pod1))
        project.environment_variables.create!(name: "POD_ID", value: "2", scope: deploy_groups(:pod2))
        EnvironmentVariable.env(deploy, deploy_groups(:pod1)).must_equal(
          "PROJECT" => "PROJECT--1", "POD_ID" => "1", "X" => "Y", "Y" => "Z"
        )
        EnvironmentVariable.env(deploy, deploy_groups(:pod2)).must_equal(
          "PROJECT" => "PROJECT--2", "POD_ID" => "2", "X" => "Y", "Y" => "Z"
        )
      end

      it "includes only project specific environment variables" do
        EnvironmentVariable.env(deploy, nil, project_specific: true).
          must_equal("PROJECT" => "PROJECT")
      end

      it "includes only project groups environment variables" do
        EnvironmentVariable.env(deploy, nil, project_specific: false).
          must_equal("X" => "Y", "Y" => "Z")
      end

      describe "secrets" do
        before do
          create_secret 'global/global/global/foobar'
          project.environment_variables.last.update_column(:value, "secret://foobar")
        end

        it "can resolve secrets" do
          EnvironmentVariable.env(deploy, nil).must_equal(
            "PROJECT" => "MY-SECRET", "X" => "Y", "Y" => "Z"
          )
        end

        it "does not resolve secrets when asked to not do it" do
          EnvironmentVariable.env(deploy, nil, resolve_secrets: false).must_equal(
            "PROJECT" => "secret://foobar", "X" => "Y", "Y" => "Z"
          )
        end

        it "fails on unfound secrets" do
          Samson::Secrets::Manager.delete 'global/global/global/foobar'
          e = assert_raises Samson::Hooks::UserError do
            EnvironmentVariable.env(deploy, nil)
          end
          e.message.must_include "Failed to resolve secret keys:\n\tfoobar"
        end

        it "does not show secret values in preview mode" do
          EnvironmentVariable.env(deploy, nil, preview: true).must_equal(
            "PROJECT" => "secret://global/global/global/foobar", "X" => "Y", "Y" => "Z"
          )
        end

        it "does not duplicate secret values in preview mode" do
          all = DeployGroup.all.map do |dg|
            EnvironmentVariable.env(deploy, dg, preview: true)
          end
          all.sort_by { |x| x["PROJECT"] }.must_equal(
            [
              {"PROJECT" => "DEPLOY", "Z" => "A", "X" => "Y", "Y" => "Z"},
              {"PROJECT" => "secret://global/global/global/foobar", "X" => "Y", "Y" => "Z"},
              {"PROJECT" => "secret://global/global/global/foobar", "X" => "Y", "Y" => "Z"}
            ]
          )
        end

        it "does not raise on missing secret values in preview mode" do
          Samson::Secrets::Manager.delete 'global/global/global/foobar'
          EnvironmentVariable.env(deploy, nil, preview: true).must_equal(
            "PROJECT" => "secret://foobar X", "X" => "Y", "Y" => "Z"
          )
        end
      end
    end
  end

  describe ".config_service_location" do
    it "shows full bucket path in the UI" do
      with_env CONFIG_SERVICE_BUCKET: "da-bucket" do
        EnvironmentVariable.config_service_location(project, nil, display: true).
          must_equal 's3://da-bucket/samson/foo'
      end
    end

    it "shows nothing in the UI when bucket is not set" do
      EnvironmentVariable.config_service_location(project, nil, display: true).must_be_nil
    end

    it "returns bucket + key for reading" do
      with_env CONFIG_SERVICE_BUCKET: "da-bucket" do
        EnvironmentVariable.config_service_location(project, deploy_group, display: false).
          must_equal ['da-bucket', 'samson/foo/pod100.yml']
      end
    end

    it "raises when bucket is not set but project is configured to read env vars" do
      assert_raises KeyError do
        EnvironmentVariable.config_service_location(project, deploy_group, display: false)
      end
    end
  end

  describe ".sort_by_scopes" do
    it "sorts by name, type, id" do
      a = environments(:production)
      b = environments(:staging)
      variables = [
        EnvironmentVariable.new(name: "A", scope_type: "Environment", scope_id: a.id),
        EnvironmentVariable.new(name: "A", scope_type: "DeployGroup", scope_id: 1),
        EnvironmentVariable.new(name: "B", scope_type: "Environment", scope_id: a.id),
        EnvironmentVariable.new(name: "A", scope_type: "Environment", scope_id: b.id),
        EnvironmentVariable.new(name: "A", scope_type: "Environment", scope_id: a.id),
        EnvironmentVariable.new(name: "A", scope_type: "Environment", scope_id: b.id),
      ]
      scopes = Environment.env_deploy_group_array
      result = EnvironmentVariable.sort_by_scopes(variables, scopes).map { |e| "#{e.name}-#{e.scope&.name}" }
      result.must_equal(["A-Production", "A-Production", "A-Staging", "A-Staging", "A-", "B-Production"])
    end
  end

  describe '.variables_to_string' do
    it 'displays environment variables as a string' do
      variables = [
        EnvironmentVariable.new(name: "FOO", value: 'bar', scope: environments(:production)),
        EnvironmentVariable.new(name: "MARCO", value: 'polo', scope: environments(:staging))
      ]

      scopes = Environment.env_deploy_group_array

      expected = %(FOO="bar" # Production\nMARCO="polo" # Staging)
      EnvironmentVariable.serialize(variables, scopes).must_equal expected
    end
  end

  describe ".allowed_inlines" do
    it "allows inline" do
      EnvironmentVariable.allowed_inlines.count.must_equal 2
    end
  end

  describe "#auditing_enabled" do
    it "creates audits for regular vars" do
      assert_difference "Audited::Audit.count", +1 do
        environment_variable.save!
      end
    end

    it "does not audit deploys which never change" do
      environment_variable.parent = deploys(:succeeded_test)
      assert_difference "Audited::Audit.count", 0 do
        environment_variable.save!
      end
    end
  end
end

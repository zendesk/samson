# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! unless defined?(Rake) # rake preloads all plugins

describe SamsonEnv do
  let(:deploy) { deploys(:succeeded_test) }
  let(:stage) { deploy.stage }
  let(:project) { stage.project }

  describe :project_permitted_params do
    it "adds params" do
      Samson::Hooks.fire(:project_permitted_params).must_include(
        environment_variables_attributes: [:name, :value, :scope_type_and_id, :_destroy, :id],
        environment_variable_group_ids: []
      )
    end
  end

  describe :after_deploy_setup do
    def fire
      job = stub(deploy: deploy, project: project)
      Samson::Hooks.fire(:after_deploy_setup, Dir.pwd, job, StringIO.new, 'abc')
    end

    run_inside_of_temp_directory

    before do
      project.environment_variables.create!(name: "HELLO", value: "world")
      project.environment_variables.create!(name: "WORLD", value: "hello")
    end

    describe ".env" do
      describe "without groups" do
        before { stage.deploy_groups.delete_all }

        it "does not modify when no variables were specified" do
          EnvironmentVariable.delete_all
          project.environment_variables.reload
          fire
          File.exist?(".env").must_equal false
        end

        it "writes to .env" do
          fire
          File.read(".env").must_equal "HELLO=\"world\"\nWORLD=\"hello\"\n"
        end

        it "overwrites .env by ignoring not required" do
          File.write(".env", "# a comment ...\nHELLO=foo")
          fire
          File.read(".env").must_equal "HELLO=\"world\"\n"
        end

        it "fails when .env has an unsatisfied required key" do
          File.write(".env", "FOO=foo")
          assert_raises(Samson::Hooks::UserError) { fire }
        end
      end

      describe "with deploy groups" do
        it "deletes the base file" do
          fire

          File.read(".env.pod-100").must_equal "HELLO=\"world\"\nWORLD=\"hello\"\n"
          refute File.exist?(".env")
        end
      end
    end

    describe "with manifest.json" do
      before do
        File.write("ENV.json", JSON.dump("other" => true))
        File.write("manifest.json", JSON.dump(
          "settings" => {
            "HELLO" => {},
            "OTHER" => {},
            "MORE" => {"required" => true},
            "OPTIONAL" => {"required" => false}
          },
          "roles" => {
            "some" => "thing"
          }
        ))
      end

      it "works without ENV.json" do
        File.unlink("ENV.json")
        project.environment_variables.create!(name: "OTHER", value: "Y")
        project.environment_variables.create!(name: "MORE", value: "Y")
        fire
        assert File.exist?("ENV.pod-100.json")
      end

      it "does not modify when no variables were specified" do
        EnvironmentVariable.delete_all
        File.read("ENV.json").must_equal "{\"other\":true}"
      end

      it "fails when missing required keys" do
        assert_raises Samson::Hooks::UserError do
          fire
        end
      end

      it "writes deploy group specific env files" do
        stage.deploy_groups << deploy_groups(:pod1)

        env_group = EnvironmentVariableGroup.create!(
          environment_variables_attributes: {
            "0" => {name: "HELLO", value: "Y"}, # overwritten by stage setting
            "1" => {name: "OTHER", value: "A"},
            "2" => {name: "MORE", value: "A"}, # overwritten by specific setting
            "3" => {name: "MORE", value: "B", scope: deploy_groups(:pod100)},
            "4" => {name: "MORE", value: "C", scope: deploy_groups(:pod1)},
            "5" => {name: "OPTIONAL", value: "A"}
          },
          name: "G1"
        )
        project.environment_variable_groups << env_group

        fire

        refute File.exist?("ENV.json")

        JSON.parse(File.read("ENV.pod-100.json")).must_equal(
          "other" => true,
          "roles" => {
            "some" => "thing"
          },
          "env" => {
            "HELLO" => "world",
            "OTHER" => "A",
            "MORE" => "B",
            "OPTIONAL" => "A"
          }
        )

        JSON.parse(File.read("ENV.pod1.json")).must_equal(
          "other" => true,
          "roles" => {
            "some" => "thing"
          },
          "env" => {
            "HELLO" => "world",
            "OTHER" => "A",
            "MORE" => "C",
            "OPTIONAL" => "A"
          }
        )
      end
    end
  end

  describe :deploy_group_env do
    it "adds env variables" do
      deploy_group = deploy_groups(:pod1)
      project.environment_variables.create!(name: "WORLD1", value: "hello", scope: environments(:staging))
      project.environment_variables.create!(name: "WORLD2", value: "hello", scope: deploy_group)
      project.environment_variables.create!(name: "WORLD3", value: "hello")
      all = Samson::Hooks.fire(:deploy_group_env, project, deploy_group).inject({}, :merge!)

      refute all["WORLD1"]
      all["WORLD2"].must_equal "hello"
      all["WORLD3"].must_equal "hello"
    end
  end
end

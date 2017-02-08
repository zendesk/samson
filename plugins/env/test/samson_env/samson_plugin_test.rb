# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

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
      end

      describe "with deploy groups" do
        it "deletes the base file" do
          fire

          File.read(".env.pod-100").must_equal "HELLO=\"world\"\nWORLD=\"hello\"\n"
          refute File.exist?(".env")
        end
      end
    end
  end

  describe :before_docker_build do
    def fire
      Samson::Hooks.fire(:before_docker_build, Dir.pwd, Build.new(project: project), StringIO.new)
    end

    run_inside_of_temp_directory

    before do
      project.environment_variables.create!(name: "HELLO", value: "world")
      project.environment_variables.create!(name: "WORLD", value: "hello")
    end

    it "writes to .env" do
      fire
      File.read(".env").must_equal "HELLO=\"world\"\nWORLD=\"hello\"\n"
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

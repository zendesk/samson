# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SamsonEnv do
  let(:deploy) { deploys(:succeeded_test) }
  let(:stage) { deploy.stage }
  let(:project) { stage.project }

  describe :project_permitted_params do
    it "adds params" do
      Samson::Hooks.fire(:project_permitted_params).flatten.must_include(
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

    it "writes group .env files" do
      fire
      Dir[".env*"].sort.must_equal [".env.pod100"]
      File.read(".env.pod100").must_equal "HELLO=\"world\"\nWORLD=\"hello\"\n"
    end

    it "removes base .env  file if it exists" do # not sure why we do this
      File.write(".env", "X")
      fire
      refute File.exist?(".env")
    end

    it "does not fail when executing job without deploy" do
      stubs(:deploy).returns(nil)
      fire
    end

    describe "without deploy groups" do
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
        ("%o" % File.stat(".env").mode).must_equal "100640"
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
      ("%o" % File.stat(".env").mode).must_equal "100640"
    end
  end

  describe :deploy_execution_env do
    let(:deploy) { deploys(:succeeded_test) }

    only_callbacks_for_plugin :deploy_execution_env

    it "adds for stages" do
      deploy.stage.environment_variables.create!(name: "WORLD", value: "hello")
      Samson::Hooks.fire(:deploy_execution_env, deploy).must_equal [{"WORLD" => "hello"}]
    end
  end

  describe :deploy_env do
    let(:deploy) { deploys(:succeeded_test) }

    only_callbacks_for_plugin :deploy_env

    it "adds env variables" do
      deploy_group = deploy_groups(:pod1)
      project.environment_variables.create!(name: "WORLD1", value: "hello", scope: environments(:staging))
      project.environment_variables.create!(name: "WORLD2", value: "hello", scope: deploy_group)
      project.environment_variables.create!(name: "WORLD3", value: "hello")
      deploy = Deploy.new(project: project)
      all = Samson::Hooks.fire(:deploy_env, deploy, deploy_group, resolve_secrets: false).inject({}, :merge!)

      refute all["WORLD1"]
      all["WORLD2"].must_equal "hello"
      all["WORLD3"].must_equal "hello"
    end

    it "is empty" do
      Samson::Hooks.fire(:deploy_env, deploy, deploy_groups(:pod1), resolve_secrets: false).
        must_equal [{}]
    end

    it "adds stage env variables" do
      deploy.stage.environment_variables.build(name: "Foo", value: "bar")
      Samson::Hooks.fire(:deploy_env, deploy, deploy_groups(:pod1), resolve_secrets: false).
        must_equal [{"Foo" => "bar"}]
    end

    it "adds deploy env variables" do
      deploy.environment_variables.build(name: "Foo", value: "bar")
      Samson::Hooks.fire(:deploy_env, deploy, deploy_groups(:pod1), resolve_secrets: false).
        must_equal [{"Foo" => "bar"}]
    end
  end

  describe :link_parts_for_resource do
    def fire(var)
      proc = Samson::Hooks.fire(:link_parts_for_resource).to_h.fetch(var.class.name)
      proc.call(var)
    end

    it "links to env var" do
      var = project.environment_variables.create!(name: "WORLD3", value: "hello")
      fire(var).must_equal ["WORLD3 on Foo", EnvironmentVariable]
    end

    it "links to external env var group" do
      group = ExternalEnvironmentVariableGroup.new(
        name: "A",
        description: "B",
        url: "https://a-bucket.s3.amazonaws.com/key?versionId=version_id",
        project: project
      )
      group.save!(validate: false)
      fire(group).must_equal ["A", ""]
    end

    it "links to scoped env var" do
      group = EnvironmentVariableGroup.create!(name: "Bar")
      var = group.environment_variables.create!(
        name: "WORLD3",
        value: "hello",
        scope_type_and_id: "Environment-#{environments(:production).id}"
      )
      fire(var).must_equal ["WORLD3 for Production on Bar", EnvironmentVariable]
    end

    it "links to env var group" do
      group = EnvironmentVariableGroup.create!(name: "FOO")
      fire(group).must_equal ["FOO", group]
    end

    it "links to deploy" do
      deploy = deploys(:succeeded_test)
      var = deploy.environment_variables.create!(name: "WORLD3", value: "hello")
      fire(var).must_equal ["WORLD3 on Deploy ##{deploy.id}", EnvironmentVariable]
    end

    it "does not crash with deleted parent" do
      var = project.environment_variables.create!(name: "WORLD3", value: "hello")
      var.reload.parent_id = 123
      fire(var).must_equal ["WORLD3 on Deleted", EnvironmentVariable]
    end
  end

  describe :can do
    def call(user, action, group)
      proc = Samson::Hooks.fire(:can).to_h.fetch(:environment_variable_groups)
      proc.call(user, action, group)
    end

    let(:group) { EnvironmentVariableGroup.create!(name: "Bar", projects: [projects(:test)]) }

    it "cannot read" do
      assert_raises(ArgumentError) { call(users(:admin), :read, group) }
    end

    it "can write as admin" do
      assert call(users(:admin), :write, group)
    end

    it "can write as project-admin" do
      assert call(users(:project_admin), :write, group)
    end

    it "cannot write as deployer" do
      refute call(users(:deployer), :write, group)
    end

    it "cannot write as other project-admin" do
      user_project_roles(:project_admin).update_column(:project_id, projects(:other).id)
      refute call(users(:project_admin), :write, group)
    end

    it "can write groups not used by any projet" do
      group.update!(projects: [])
      assert call(users(:project_admin), :write, group)
    end
  end

  describe :stage_permitted_params do
    it "allows environment attributes" do
      Samson::Hooks.only_callbacks_for_plugin("env", :stage_permitted_params) do
        Samson::Hooks.fire(:stage_permitted_params).map(&:keys).must_equal [[:environment_variables_attributes]]
      end
    end
  end

  describe :deploy_permitted_params do
    it "includes the environment_variables attributes" do
      Samson::Hooks.fire(:deploy_permitted_params).must_include(
        environment_variables_attributes: [
          :name, :value, :scope_type_and_id, :_destroy, :id
        ]
      )
    end
  end

  describe :project_allowed_includes do
    it "includes external env var groups with external env configured" do
      with_env EXTERNAL_ENV_GROUP_S3_REGION: "us-east-1", EXTERNAL_ENV_GROUP_S3_BUCKET: "a-bucket" do
        Samson::Hooks.fire(:project_allowed_includes).must_include(
          [:external_environment_variable_groups]
        )
      end
    end

    it "does not include external env var groups when not configured" do
      Samson::Hooks.fire(:project_allowed_includes).must_equal(
        [[]]
      )
    end
  end
end

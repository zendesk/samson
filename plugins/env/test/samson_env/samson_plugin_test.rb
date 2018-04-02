# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: 3

describe SamsonEnv do
  let(:deploy) { deploys(:succeeded_test) }
  let(:stage) { deploy.stage }
  let(:project) { stage.project }

  describe "view callbacks" do
    let(:view_context) do
      view_context = ActionView::Base.new(ActionController::Base.view_paths)

      class << view_context
        include Rails.application.routes.url_helpers
      end

      view_context
    end

    describe 'deploy_tab_nav' do
      it 'renders environment variable diff deploy tab nav' do
        result = Samson::Hooks.render_views(:deploy_confirmation_tab_nav, view_context)

        expected = %(<li><a href="#environment-variables" data-toggle="tab">Environment variables</a></li>\n)
        result.must_equal expected
      end
    end

    describe 'deploy_tab_body' do
      it 'renders environment variable diff deploy tab with new deploy' do
        new_deploy = Deploy.new(deploy.attributes.except('id', 'created_at', 'updated_at'))
        new_deploy.expects(:serialized_environment_variables).returns('THING=thing # All')

        view_context.instance_variable_set(:@deploy, new_deploy)

        result = Samson::Hooks.render_views(:deploy_confirmation_tab_body, view_context)

        result.must_include '<ins>THING=thing # All</ins>'
      end

      it 'renders environment variable diff deploy tab with preexisting deploy' do
        other_deploy = Deploy.create!(deploy.attributes.except('id', 'created_at', 'updated_at'))
        other_deploy .env_state = "a\nb\nc"

        view_context.instance_variable_set(:@deploy, other_deploy)

        result = Samson::Hooks.render_views(:deploy_confirmation_tab_body, view_context)

        result.must_include 'class="diff"'
        result.must_include '<ins>a</ins>'
        result.must_include '<ins>b</ins>'
        result.must_include '<ins>c</ins>'
      end

      it 'renders no changes were made if env_state is the same' do
        other_deploy = Deploy.create!(deploy.attributes.except('id', 'created_at', 'updated_at'))
        view_context.instance_variable_set(:@deploy, other_deploy)

        Samson::Hooks.render_views(:deploy_confirmation_tab_body, view_context).must_include 'No changes.'
      end
    end
  end

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
          ("%o" % File.stat(".env").mode).must_equal "100640"
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
      ("%o" % File.stat(".env").mode).must_equal "100640"
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

  describe :link_parts_for_resource do
    it "links to env var" do
      var = project.environment_variables.create!(name: "WORLD3", value: "hello")
      proc = Samson::Hooks.fire(:link_parts_for_resource).to_h.fetch("EnvironmentVariable")
      proc.call(var).must_equal ["WORLD3 on Foo", EnvironmentVariable]
    end

    it "links to scoped env var" do
      group = EnvironmentVariableGroup.create!(name: "Bar")
      var = group.environment_variables.create!(
        name: "WORLD3",
        value: "hello",
        scope_type_and_id: "Environment-#{environments(:production).id}"
      )
      proc = Samson::Hooks.fire(:link_parts_for_resource).to_h.fetch("EnvironmentVariable")
      proc.call(var).must_equal ["WORLD3 for Production on Bar", EnvironmentVariable]
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
      group.update_attributes!(projects: [])
      assert call(users(:project_admin), :write, group)
    end
  end
end

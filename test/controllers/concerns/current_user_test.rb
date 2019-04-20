# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

class CurrentUserConcernTest < ActionController::TestCase
  class CurrentUserTestController < ApplicationController
    include CurrentProject
    include CurrentStage
    include CurrentUser

    def whodunnit
      render plain: Audited.store[:current_user].call.name
    end

    def change
      Stage.find(params[:id]).update_attribute(:name, 'MUUUU')
      head :ok
    end

    def super_admin_action
      authorize_super_admin!
      head :ok
    end

    def admin_action
      authorize_admin!
      head :ok
    end

    def deployer_action
      authorize_deployer!
      head :ok
    end

    def project_deployer_action
      authorize_project_deployer!
      head :ok
    end

    def project_admin_action
      authorize_project_admin!
      head :ok
    end

    def unauthorized_action
      unauthorized!
    end

    def resourced_action
      @project = Project.find(params[:project_id]) if params[:project_id]
      authorize_resource!
      head :ok
    end
  end

  tests CurrentUserTestController
  use_test_routes CurrentUserTestController

  def self.authorized(method, action, params)
    it "is authorized to #{method} #{action}" do
      public_send method, action, params: params
      assert_response :success
    end
  end

  as_a :viewer do
    it "knows who did something" do
      get :whodunnit, params: {test_route: true}
      response.body.must_equal users(:viewer).name
    end

    it "records changes" do
      stage = stages(:test_staging)
      get :change, params: {test_route: true, id: stage.id}
      stage.reload.name.must_equal 'MUUUU'
      stage.audits.size.must_equal 1
    end

    describe "#current_user=" do
      it "sets the user and persists it for the next request" do
        @controller.send(:current_user=, user)
        @controller.send(:current_user).must_equal user
        session.inspect.must_equal({"warden.user.default.key" => user.id}.inspect)
      end
    end

    describe "#logout!" do
      it "unsets the user and logs them out" do
        @controller.send(:current_user=, user)
        @controller.send(:logout!)
        @controller.send(:current_user).must_be_nil
        session.inspect.must_equal({}.inspect)
      end
    end

    unauthorized :get, :deployer_action, test_route: true
    unauthorized :get, :admin_action, test_route: true
    unauthorized :get, :super_admin_action, test_route: true
  end

  as_a :deployer do
    authorized :get, :deployer_action, test_route: true
    unauthorized :get, :admin_action, test_route: true
    unauthorized :get, :super_admin_action, test_route: true

    it "can access any project" do
      UserProjectRole.delete_all
      get :project_deployer_action, params: {project_id: Project.first.id, test_route: true}
      assert_response :success
    end

    it "cannot access admin" do
      get :project_admin_action, params: {project_id: Project.first.id, test_route: true}
      assert_response :unauthorized
    end
  end

  as_a :project_deployer do
    it "can access allowed projects" do
      get :project_deployer_action, params: {project_id: Project.first.id, test_route: true}
      assert_response :success
    end

    it "cannot access forbidden projects" do
      UserProjectRole.delete_all
      get :project_deployer_action, params: {project_id: Project.first.id, test_route: true}
      assert_response :unauthorized
    end

    it "cannot access admin" do
      get :project_admin_action, params: {project_id: Project.first.id, test_route: true}
      assert_response :unauthorized
    end
  end

  as_a :project_admin do
    it "can access allowed projects" do
      get :project_admin_action, params: {project_id: Project.first.id, test_route: true}
      assert_response :success
    end

    it "cannot access forbidden projects" do
      UserProjectRole.delete_all
      get :project_admin_action, params: {project_id: Project.first.id, test_route: true}
      assert_response :unauthorized
    end
  end

  as_a :admin do
    authorized :get, :deployer_action, test_route: true
    authorized :get, :admin_action, test_route: true
    unauthorized :get, :super_admin_action, test_route: true

    it "can access any project" do
      get :project_admin_action, params: {project_id: Project.first.id, test_route: true}
      assert_response :success
    end

    it "can access any project deploy" do
      get :project_deployer_action, params: {project_id: Project.first.id, test_route: true}
      assert_response :success
    end
  end

  as_a :super_admin do
    authorized :get, :deployer_action, test_route: true
    authorized :get, :admin_action, test_route: true
    authorized :get, :super_admin_action, test_route: true
  end

  describe "logging" do
    as_a :viewer do
      it "logs unautorized so we can see it in test output for easy debugging" do
        Rails.logger.expects(:warn)
        get :unauthorized_action, params: {test_route: true}
        assert_response :unauthorized
      end
    end

    it "logs unautorized so we can see it in test output for easy debugging" do
      Rails.logger.expects(:warn)
      get :whodunnit, params: {test_route: true}
      assert_response :unauthorized
    end

    it "fails the request so during a test we can see failures instead of assert_response lying" do
      get :whodunnit, params: {test_route: true}
      assert_response :unauthorized
    end
  end

  describe "#authorize_resource!" do
    def perform_get(add = {})
      get :resourced_action, params: add.merge(test_route: true)
    end

    before do
      @controller.stubs(:controller_name).returns('locks')
      login_as :admin
    end

    it "renders when authorized" do
      perform_get
      assert_response :success
    end

    it "renders when authorized for builds" do
      @controller.stubs(:controller_name).returns('builds')
      perform_get
      assert_response :success
    end

    it "render without current projects" do
      @controller.stubs(:respond_to?).with(:current_project, true).returns(false)
      @controller.stubs(:respond_to?).with(:request).returns(true)
      perform_get
      assert_response :success
    end

    it "fails for unknown controller" do
      @controller.unstub(:controller_name)
      e = assert_raises(ArgumentError) { perform_get }
      e.message.must_equal "Unsupported resource_namespace current_user_test"
    end

    describe 'users' do
      before { @controller.stubs(:controller_name).returns('users') }

      it "renders when authorized for admin action" do
        login_as :admin
        @controller.stubs(:action_name).returns('index')
        perform_get
        assert_response :success
      end

      it "renders when authorized for super admin action" do
        login_as :super_admin
        @controller.stubs(:action_name).returns('destroy')
        perform_get
        assert_response :success
      end
    end

    describe "when user is not authorized to do everything" do
      before { login_as :project_deployer }

      it "does not render when unauthorized" do
        perform_get
        assert_response :unauthorized
      end

      it "fails when not authorized via the project" do
        users(:project_deployer).user_project_roles.delete_all
        perform_get(project_id: projects(:test).id)
        assert_response :unauthorized
      end
    end
  end

  describe "#can?" do
    it "does not override when scope is passed as nil since that has special meaning" do
      AccessControl.expects(:can?).with(nil, :write, :locks, nil)
      @controller.send(:can?, :write, :locks, nil)
    end
  end
end

# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

class CurrentUserConcernTest < ActionController::TestCase
  class CurrentUserTestController < ApplicationController
    include CurrentUser
    include CurrentProject

    def whodunnit
      render plain: "#{PaperTrail.whodunnit} -- #{PaperTrail.whodunnit_user.name}"
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

    def resource_action
      @project = Project.find(params[:project_id]) if params[:project_id]
      authorize_resource!
      head :ok
    end
  end

  tests CurrentUserTestController
  use_test_routes CurrentUserTestController
  with_paper_trail

  def self.authorized(method, action, params)
    it "is authorized to #{method} #{action}" do
      public_send method, action, params: params
      assert_response :success
    end
  end

  as_a_viewer do
    # make sure nothing leaks
    before { refute PaperTrail.whodunnit_user }
    after { refute PaperTrail.whodunnit_user }

    it "knows who did something" do
      get :whodunnit, params: {test_route: true}
      response.body.must_equal "#{users(:viewer).id} -- #{users(:viewer).name}"
    end

    it "does not assign to different users by accident" do
      before = PaperTrail.whodunnit # FIXME: this is not nil on travis ... capturing current value instead
      get :whodunnit, params: {test_route: true}
      PaperTrail.whodunnit.must_equal before
    end

    it "records changes" do
      stage = stages(:test_staging)
      get :change, params: {test_route: true, id: stage.id}
      stage.reload.name.must_equal 'MUUUU'
      stage.versions.size.must_equal 1
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

  as_a_deployer do
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

  as_a_project_deployer do
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

  as_a_project_admin do
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

  as_a_admin do
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

  as_a_super_admin do
    authorized :get, :deployer_action, test_route: true
    authorized :get, :admin_action, test_route: true
    authorized :get, :super_admin_action, test_route: true
  end

  describe "logging" do
    as_a_viewer do
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
      get :resource_action, params: add.merge(test_route: true)
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

    it "fails for unknown controller" do
      @controller.unstub(:controller_name)
      e = assert_raises(RuntimeError) { perform_get }
      e.message.must_equal "Unsupported controller"
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

      it "renders when authorized via the project" do
        perform_get(project_id: projects(:test).id)
        assert_response :success
      end

      it "fails when not authorized via the project" do
        users(:project_deployer).user_project_roles.delete_all
        perform_get(project_id: projects(:test).id)
        assert_response :unauthorized
      end
    end
  end
end

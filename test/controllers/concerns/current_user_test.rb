require_relative '../../test_helper'

SingleCov.covered!

class CurrentUserConcernTest < ActionController::TestCase
  class CurrentUserTestController < ApplicationController
    include CurrentUser
    include CurrentProject

    def whodunnit
      render plain: PaperTrail.whodunnit.to_s.dup
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
  end

  tests CurrentUserTestController
  use_test_routes CurrentUserTestController

  def self.authorized(method, action, params)
    it "is authorized to #{method} #{action}" do
      send method, action, params
      refute_unauthorized
    end
  end

  as_a_viewer do
    around { |t| PaperTrail.with_whodunnit(nil, &t) }

    it "knows who did something" do
      get :whodunnit, test_route: true
      response.body.must_equal users(:viewer).id.to_s
    end

    it "does not assign to different users by accident" do
      before = PaperTrail.whodunnit # FIXME: this is not nil on travis ... capturing current value instead
      get :whodunnit, test_route: true
      PaperTrail.whodunnit.must_equal before
    end

    it "records changes" do
      stage = stages(:test_staging)
      PaperTrail.with_logging do
        get :change, test_route: true, id: stage.id
      end
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
        @controller.send(:current_user).must_equal nil
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
      get :project_deployer_action, project_id: Project.first.id, test_route: true
      refute_unauthorized
    end

    it "cannot access admin" do
      get :project_admin_action, project_id: Project.first.id, test_route: true
      assert_unauthorized
    end
  end

  as_a_project_deployer do
    it "can access allowed projects" do
      get :project_deployer_action, project_id: Project.first.id, test_route: true
      refute_unauthorized
    end

    it "cannot access forbidden projects" do
      UserProjectRole.delete_all
      get :project_deployer_action, project_id: Project.first.id, test_route: true
      assert_unauthorized
    end

    it "cannot access admin" do
      get :project_admin_action, project_id: Project.first.id, test_route: true
      assert_unauthorized
    end
  end

  as_a_project_admin do
    it "can access allowed projects" do
      get :project_admin_action, project_id: Project.first.id, test_route: true
      refute_unauthorized
    end

    it "cannot access forbidden projects" do
      UserProjectRole.delete_all
      get :project_admin_action, project_id: Project.first.id, test_route: true
      assert_unauthorized
    end
  end

  as_a_admin do
    authorized :get, :deployer_action, test_route: true
    authorized :get, :admin_action, test_route: true
    unauthorized :get, :super_admin_action, test_route: true

    it "can access any project" do
      get :project_admin_action, project_id: Project.first.id, test_route: true
      refute_unauthorized
    end

    it "can access any project deploy" do
      get :project_deployer_action, project_id: Project.first.id, test_route: true
      refute_unauthorized
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
        get :unauthorized_action, test_route: true
        assert_unauthorized
      end
    end

    it "logs unautorized so we can see it in test output for easy debugging" do
      Rails.logger.expects(:warn)
      get :whodunnit, test_route: true
      assert_unauthorized
    end
  end
end

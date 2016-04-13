require_relative '../../test_helper'

SingleCov.covered!

describe "ProjectLevelAuthorization Controller" do
  class ProjectLevelAuthorizationTestController < ApplicationController
    include ProjectLevelAuthorization
    before_action :authorize_project_deployer!, only: :deploy
    before_action :authorize_project_admin!, only: :admin

    def deploy
      head :ok
    end

    def admin
      head :ok
    end
  end

  tests ProjectLevelAuthorizationTestController
  use_test_routes

  as_a_project_deployer do
    it "can access allowed projects" do
      get :deploy, project_id: Project.first.id, test_route: true
      refute_unauthorized
    end

    it "cannot access forbidden projects" do
      UserProjectRole.delete_all
      get :deploy, project_id: Project.first.id, test_route: true
      assert_unauthorized
    end

    it "cannot access admin" do
      get :admin, project_id: Project.first.id, test_route: true
      assert_unauthorized
    end
  end

  as_a_deployer do
    it "can access any project" do
      UserProjectRole.delete_all
      get :deploy, project_id: Project.first.id, test_route: true
      refute_unauthorized
    end

    it "cannot access admin" do
      get :admin, project_id: Project.first.id, test_route: true
      assert_unauthorized
    end
  end

  as_a_project_admin do
    it "can access allowed projects" do
      get :admin, project_id: Project.first.id, test_route: true
      refute_unauthorized
    end

    it "cannot access forbidden projects" do
      UserProjectRole.delete_all
      get :admin, project_id: Project.first.id, test_route: true
      assert_unauthorized
    end
  end

  as_a_admin do
    it "can access any project" do
      get :admin, project_id: Project.first.id, test_route: true
      refute_unauthorized
    end

    it "can access any project deploy" do
      get :deploy, project_id: Project.first.id, test_route: true
      refute_unauthorized
    end
  end
end

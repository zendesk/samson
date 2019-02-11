# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

class WrapInWithDeletedConcernTest < ActionController::TestCase
  class WrapInWithDeletedTestController < ApplicationController
    include WrapInWithDeleted
    include CurrentProject

    def show
      deploy = Deploy.find(params[:id])
      render inline: deploy.class.name.to_s
    end

    def project
      render inline: '<%= current_project.name %>'
    end
  end

  tests WrapInWithDeletedTestController
  use_test_routes WrapInWithDeletedTestController

  let(:project) { projects(:test) }
  let(:deploy) { deploys(:succeeded_test) }

  before { login_as(users(:viewer)) }

  it "fetch deleted deploy" do
    deploy.soft_delete!
    get :show, params: {project_id: project.id, id: deploy.id, test_route: true, with_deleted: true}
    response.body.must_equal 'Deploy'
  end

  it "fails without params" do
    deploy.soft_delete!
    assert_raises ActiveRecord::RecordNotFound do
      get :show, params: {project_id: project.id, id: deploy.id, test_route: true}
    end
  end

  it "fetch deleted project" do
    project.soft_delete(validate: false)
    get :project, params: {project_id: project.id, id: deploy.id, test_route: true, with_deleted: true}
    response.body.must_equal project.name
  end
end

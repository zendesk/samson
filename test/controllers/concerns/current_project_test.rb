# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

class CurrentProjectConcernTest < ActionController::TestCase
  class CurrentProjectTestController < ApplicationController
    include CurrentProject

    def show
      render inline: '<%= current_project.class.name %>'
    end
  end

  tests CurrentProjectTestController
  use_test_routes CurrentProjectTestController

  let(:project) { projects(:test) }

  before { login_as(users(:viewer)) }

  it "finds current project" do
    get :show, params: {project_id: project.id, test_route: true}
    response.body.must_equal 'Project'
  end

  it "fails with invalid project id" do
    assert_raises ActiveRecord::RecordNotFound do
      get :show, params: {project_id: 123456, test_route: true}
    end
  end

  it "does not fail without project" do
    get :show, params: {test_route: true}
    response.body.must_equal 'NilClass'
  end
end

# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered! uncovered: 1

class CurrentStageConcernTest < ActionController::TestCase
  class CurrentStageTestController < ApplicationController
    include CurrentProject
    include CurrentStage

    def show
      render inline: '<%= current_stage.class.name %>'
    end
  end

  tests CurrentStageTestController
  use_test_routes CurrentStageTestController

  let(:project) { projects(:test) }
  let(:stage) { stages(:test_staging) }

  before { login_as(users(:viewer)) }

  it "finds current stage" do
    get :show, params: {project_id: project.id, id: stage.id, test_route: true}
    response.body.must_equal 'Stage'
  end

  it "fails with invalid stage id" do
    assert_raises ActiveRecord::RecordNotFound do
      get :show, params: {project_id: project.id, id: 123456, test_route: true}
    end
  end

  it "does not fail without stage" do
    get :show, params: {test_route: true}
    response.body.must_equal 'NilClass'
  end
end

# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe ReferencesController do
  before do
    reference_service = ReferencesService.new(projects(:test))
    reference_service.stubs(:find_git_references).returns(%w[master test_user/test_branch])
    ReferencesService.stubs(:new).returns(reference_service)
  end

  as_a_viewer do
    unauthorized :get, :index, project_id: :foo
  end

  as_a_project_deployer do
    describe '#index' do
      it 'returns the git references for the project test' do
        get :index, params: {project_id: projects(:test).to_param, format: :json}
        response.content_type.must_equal 'application/json'
        assigns(:references).must_equal %w[master test_user/test_branch]
      end
    end
  end
end

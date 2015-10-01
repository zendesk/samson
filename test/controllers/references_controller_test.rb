require_relative '../test_helper'

describe ReferencesController do

  before(:all) do
    reference_service = ReferencesService.new(projects(:test))
    reference_service.stubs(:find_git_references).returns(%w(master test_user/test_branch))
    ReferencesService.stubs(:new).returns(reference_service)
  end

  describe 'a GET to :index' do
    describe 'as json' do
      as_a_deployer do

        it 'returns the git references for the project test' do
          get :index, project_id: projects(:test).to_param, format: :json
          response.content_type.must_equal 'application/json'
          assigns(:references).must_equal %w(master test_user/test_branch)
        end
      end

      as_a_viewer_project_deployer do

        it 'returns the git references for the project test' do
          get :index, project_id: projects(:test).to_param, format: :json
          response.content_type.must_equal 'application/json'
          assigns(:references).must_equal %w(master test_user/test_branch)
        end

      end
    end
  end
end

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
        it 'renders json' do
          get :index, project_id: projects(:test).to_param, format: :json
          assert_response :ok
          assert_equal 'application/json', response.content_type
          json_response = JSON.parse response.body
          json_response.size.must_equal 2
          json_response.must_equal %w(master test_user/test_branch)
        end
      end
    end
  end
end


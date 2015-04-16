require_relative '../../test_helper'

describe Admin::ProjectsController do
  describe 'authorization' do
    let(:project) { projects(:test) }

    as_a_deployer do
      unauthorized :get, :show
    end

    as_a_admin do
      it 'renders' do
        get :show
        assert_response :success
        assert_template :show
      end


      it 'paginates' do
        mock = MiniTest::Mock.new
        mock.expect :call, Project.page(2), ['2']
        Project.stub(:page, mock) do
          get :show, page: 2
        end
        mock.verify
      end
    end
  end
end

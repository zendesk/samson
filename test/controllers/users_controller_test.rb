require_relative '../test_helper'

describe UsersController do
  let(:project) { projects(:test) }


  describe "a GET to #index" do
    as_a_viewer do
      unauthorized :get, :index, project_id: :foo
    end

    as_a_deployer do
      unauthorized :get, :index, project_id: :foo
    end

    as_a_admin do
      it 'responds successfully' do
        get :index, project_id: project.to_param
        users = User.all
        assert_template :index
        assigns(:users).wont_be_nil
        assigns(:users).wont_be_empty
        assigns(:users).size.must_equal users.size
      end

      it 'responds successfully to a JSON request' do
        get :index, project_id: project.to_param, format: 'json'
        users = User.all
        assigns(:users).wont_be_nil
        result = JSON.parse(response.body)
        result['users'].wont_be_nil
        result['users'].wont_be_nil
        result['users'].wont_be_empty
        result['users'].length.must_equal users.size
        result['users'].each  do | user |
          user_info = User.find_by(name: user['name'])
          user_info.wont_be_nil
        end
      end

      it 'responds as expected to a filtered search' do
        get :index, project_id: project.to_param, search: "Admin"
        users = User.search("Admin").page(1)
        assert_template :index
        assigns(:users).wont_be_nil
        assigns(:users).wont_be_empty
        assigns(:users).size.must_equal users.size
      end
    end

    as_a_deployer_project_admin do
      it 'responds successfully' do
        get :index, project_id: project.to_param
        users = User.all
        assert_template :index
        assigns(:users).wont_be_nil
        assigns(:users).wont_be_empty
        assigns(:users).size.must_equal users.size
      end

      it 'responds successfully to a JSON request' do
        get :index, project_id: project.to_param, format: 'json'
        users = User.all
        assigns(:users).wont_be_nil
        result = JSON.parse(response.body)
        result['users'].wont_be_nil
        users = result['users']
        users.wont_be_nil
        users.wont_be_empty
        users.length.must_equal users.size
        users.each  do | user |
          user_info = User.find_by(name: user['name'])
          user_info.wont_be_nil
        end
      end

      it 'responds as expected to a filtered search' do
        get :index, project_id: project.to_param, search: "Admin"
        users = User.search("Admin").page(1)
        assert_template :index
        assigns(:users).wont_be_nil
        assigns(:users).wont_be_empty
        assigns(:users).size.must_equal users.size
      end
    end
  end
end

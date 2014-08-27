require 'test_helper'

describe Admin::UsersController do
  describe 'a GET to #show' do
    before do
      get :index
    end

    as_a_admin do
      it 'succeeds' do
        assert_template :index
      end
    end

    as_a_deployer do
      unauthorized :get, :index
    end
  end

  describe 'a json GET to #show' do
    before do
      get :index, :format => :json
    end

    as_a_admin do
      it 'succeeds' do
        response.success?.must_equal true
        json_response = JSON.parse response.body
        user_list = json_response['users']
        assert_not_nil user_list
        user_list.each  do | u |
          user_info = User.find_by(name: u['name'])
          assert_not_nil user_info
          assert_equal user_info.email, u['email']
        end
      end
    end

    as_a_deployer do
      unauthorized :get, :index, :format => :json
    end
  end

  describe 'a DELETE to #destroy' do

    let(:user) { users(:viewer) }

    as_a_deployer do
      unauthorized :delete, :destroy, project_id: 1, id: 1
    end

    as_a_admin do
      unauthorized :delete, :destroy, project_id: 1, id: 1
    end

    as_a_super_admin do
      setup do
        delete :destroy, id: user.id
      end

      it 'soft delete the user' do
        user.reload.deleted_at.wont_be_nil
      end

      it 'redirects to admin users page' do
        assert_redirected_to admin_users_path
      end
    end

  end

end

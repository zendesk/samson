require_relative '../../test_helper'

describe Admin::UsersController do
  describe 'a GET to #show' do
    before do
      get :index
    end

    as_a_admin do
      it 'succeeds' do
        assert_template :index, partial: '_search_bar'
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
          user_info.wont_be_nil
          user_info.email.must_equal u['email']
        end
      end
    end

    as_a_deployer do
      unauthorized :get, :index, :format => :json
    end
  end

  describe 'a json get to #show with a search string' do

    as_a_admin do

      it 'succeeds and fetches a single user' do
        get :index, search: 'Super Admin' , :format => :json

        response.success?.must_equal true
        json_response = JSON.parse response.body
        user_list = json_response['users']
        user_list.wont_be_nil
        user_list.size.must_equal 1
        user_info = user_list[0]
        user_info['name'].must_equal 'Super Admin'
        user_info['email'].must_equal 'super-admin@example.com'
        user_info['role_id'].must_equal Role::SUPER_ADMIN.id
      end

      it 'succeeds and with search as empty fetches all users' do
        get :index, search: '' , :format => :json

        response.success?.must_equal true
        json_response = JSON.parse response.body
        user_list = json_response['users']
        user_list.wont_be_nil
        user_list.size.must_equal 7

        user_list.each  do | u |
          user_info = User.find_by(name: u['name'])
          user_info.wont_be_nil
          user_info.email.must_equal u['email']
        end
      end

      it 'index page should render with search partial and search box should be empty' do
        get :index

        assert_template :index, partial: '_search_bar'
        input = css_select('#search')
        input.size.must_equal 1
        expected = '<input class="form-control" id="search" name="search" placeholder="Search" type="text" />'
        input[0].to_s.must_equal expected
      end

      it 'index page search box should contain the query' do
        get :index, search: 'Super Admin'

        assert_template :index,  partial: '_search_bar'
        assert_select '#search[value=?]', 'Super Admin'
        assert_select 'tbody' do
          assert_select 'tr', 1
        end
      end

    end

    as_a_deployer do
      unauthorized :get, :index, search: 'Super Admin', :format => :json
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

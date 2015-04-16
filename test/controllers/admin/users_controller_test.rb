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
  end

  describe 'a json get to #show with a search string' do
    as_a_admin do
      it 'succeeds and fetches a single user' do
        get :index, search: 'Super Admin' , :format => :json

        response.success?.must_equal true
        assigns(:users).must_equal [users(:super_admin)]
      end

      it 'succeeds and with search as empty fetches all users' do
        get :index, search: ''

        response.success?.must_equal true
        user_list = assigns(:users)
        user_list.wont_be_nil
        per_page = User.max_per_page || Kaminari.config.default_per_page
        assigns(:users).size.must_equal [User.count, per_page].min
      end

      it 'index page should render with search partial and search box should be empty' do
        get :index

        assert_template :index, partial: '_search_bar'
        assert_select '#search' do
          assert_select '[name="search"]'
          assert_select '[type="text"]'
          assert_select '[class="form-control"]'
          assert_select ':not([value])'
        end
      end

      it 'index page search box should contain the query' do
        get :index, search: 'Super Admin'

        assert_template :index,  partial: '_search_bar'
        assert_select '#search' do
          assert_select '[name="search"]'
          assert_select '[type="text"]'
          assert_select '[class="form-control"]'
          assert_select '[value="Super Admin"]'
        end
        assert_select 'tbody' do
          assert_select 'tr', 1
        end
      end
    end
  end

  describe 'a DELETE to #destroy' do
    let(:user) { users(:viewer) }

    as_a_deployer do
      it 'doesn\'t work for deployers' do
        unauthorized :delete, :destroy, id: user.id
      end
    end

    as_a_admin do
      it 'doesn\'t work for admins' do
        unauthorized :delete, :destroy, id: user.id
      end
    end

    as_a_super_admin do

      it 'soft delete the user' do
        delete :destroy, id: user.id
        user.reload.deleted_at.wont_be_nil
        assert_redirected_to admin_users_path
      end
    end
  end
end

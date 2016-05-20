require_relative '../../test_helper'

SingleCov.covered!

describe Admin::UsersController do
  as_a_viewer do
    unauthorized :get, :index
    unauthorized :get, :show, id: 1
    unauthorized :delete, :destroy, project_id: 1, id: 1
    unauthorized :put, :update, id: 1
  end

  as_a_deployer do
    unauthorized :get, :index
    unauthorized :get, :show, id: 1
    unauthorized :delete, :destroy, id: 1
    unauthorized :put, :update, id: 1
  end

  as_a_admin do
    unauthorized :delete, :destroy, id: 1
    unauthorized :put, :update, id: 1

    describe 'a html GET to #index' do
      it 'succeeds' do
        get :index
        assert_template :index, partial: '_search_bar'
      end

      it 'renders with search partial and search box should be empty' do
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

        assert_template :index, partial: '_search_bar'
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

    describe 'a json GET to #index' do
      it 'succeeds' do
        get :index, format: :json

        response.success?.must_equal true
        json_response = JSON.parse response.body
        user_list = json_response['users']
        assert_not_nil user_list
        user_list.each do |u|
          user_info = User.find_by(name: u['name'])
          user_info.wont_be_nil
          user_info.email.must_equal u['email']
        end
      end

      it 'succeeds and fetches a single user' do
        get :index, search: 'Super Admin', format: :json

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
    end

    describe 'a csv GET to #index' do
      before do
        get :index, format: :csv
      end

      it 'succeeds, accurate and complete' do
        response.success?.must_equal true
        csv_response = CSV.parse(response.body)
        csv_headers = csv_response.shift
        rowcount = csv_headers.pop.to_i
        usercount = csv_headers.pop.to_i
        User.count.must_equal usercount
        (User.count + UserProjectRole.joins(:user, :project).count).must_equal rowcount
        rowcount.must_equal csv_response.length
        assert_not_nil csv_response
        csv_response.each do |u|
          user_info = User.find_by(id: u[0])
          user_info.wont_be_nil
          user_info.name.must_equal u[1]
          user_info.email.must_equal u[2]
          if u[3] == ""
            u[4].must_equal "SYSTEM"
            user_info.role.name.must_equal u[5]
          else
            user_project_role_info = UserProjectRole.find_by(user_id: u[0], project_id: u[3])
            user_project_role_info.wont_be_nil
            user_project_role_info.project.name.must_equal u[4]
            user_project_role_info.role.name.must_equal u[5]
          end
        end
      end
    end

    describe 'a GET to #show' do
      let(:modified_user) { users(:viewer) }

      it 'succeeds' do
        get :show, id: modified_user.id
        assert_template :show, partial: '_project', locals: { user: modified_user }
      end
    end
  end

  as_a_super_admin do
    describe 'a PUT to #update' do
      let(:modified_user) { users(:viewer) }

      it 'updates the user role' do
        put :update, id: modified_user.id, user: {role_id: 2}
        modified_user.reload.role_id.must_equal 2
        assert_response :success
      end

      it 'clears the access request pending flag' do
        modified_user.update!(access_request_pending: true)
        put :update, id: modified_user.id, user: {role_id: Role::DEPLOYER.id}
        modified_user.reload.access_request_pending.must_equal false
      end

      it 'renders when it fails' do
        put :update, id: modified_user.id, user: {role_id: 5}
        assert_response :bad_request
      end
    end

    describe 'a DELETE to #destroy' do
      let(:modified_user) { users(:viewer) }

      it 'soft delete the user' do
        delete :destroy, id: modified_user.id
        modified_user.reload.deleted_at.wont_be_nil
        assert_redirected_to admin_users_path
      end
    end
  end
end

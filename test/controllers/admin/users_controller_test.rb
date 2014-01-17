require 'test_helper'

describe Admin::UsersController do
  describe 'a GET to #show' do
    before do
      get :show
    end

    as_a_admin do
      it 'succeeds' do
        assert_template :show
      end
    end

    as_a_deployer do
      it 'redirects to home page' do
        assert_redirected_to root_path
      end
    end
  end

  describe 'a DELETE to #destroy' do

    let(:user) { users(:viewer) }

    before do
      delete :destroy, id: user.id
    end

    as_a_admin do
      it 'soft delete the user' do
        user.reload.deleted_at.wont_be_nil
      end

      it 'redirects to admin users page' do
        assert_redirected_to admin_users_path
      end
    end

    as_a_deployer do
      it 'redirects to home page' do
        assert_redirected_to root_path
      end
    end
  end
end

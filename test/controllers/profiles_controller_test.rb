require_relative '../test_helper'

SingleCov.covered!

describe ProfilesController do
  as_a_viewer do
    describe 'a GET to #show' do
      it 'renders' do
        get :show
        assert_template :show
      end
    end

    describe 'a PUT to #update' do
      it 'updates' do
        put :update, user: {name: 'Hans'}
        assert_redirected_to profile_path
        user.reload.name.must_equal 'Hans'
      end

      it 'renders when it fails to update' do
        User.any_instance.expects(:update_attributes).returns false
        put :update, user: {name: 'Hans'}
        assert_template :show
      end
    end
  end
end

# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe ProfilesController do
  as_a :viewer do
    describe '#show' do
      it 'renders' do
        get :show
        assert_template :show
      end
    end

    describe '#update' do
      it 'updates' do
        put :update, params: {user: {name: 'Hans'}}
        assert_redirected_to profile_path
        user.reload.name.must_equal 'Hans'
      end

      it 'renders when it fails to update' do
        User.any_instance.expects(:update_attributes).returns false
        put :update, params: {user: {name: 'Hans'}}
        assert_template :show
      end

      describe 'github username' do
        it 'updates with valid username' do
          put :update, params: {user: {github_username: 'foo'}}
          user.reload.github_username.must_equal 'foo'
        end

        it 'doesn`t update with invalid username' do
          put :update, params: {user: {github_username: 'foo_5$'}}
          user.reload.github_username.wont_equal 'foo_5$'
        end
      end
    end
  end
end

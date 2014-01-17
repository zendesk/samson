require 'test_helper'

class Admin::UsersControllerTest < ActionController::TestCase
  describe 'a GET to #show' do
    as_a_admin do
      setup do
        get '/admin/users'
      end

      it 'succeeds' do
        assert_template :show
      end
    end
  end
end

# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe UserMergesController do
  as_a :admin do
    unauthorized :get, :new, user_id: 1
    unauthorized :post, :create, user_id: 1
  end

  as_a :super_admin do
    describe "#new" do
      it "renders" do
        get :new, params: {user_id: users(:admin).id}
        assert_response :success
      end
    end

    describe "#create" do
      it "merges the users and lets the original now log in with new credentials" do
        assert_difference 'User.count', -1 do
          post :create, params: {user_id: user.id, merge_target_id: users(:deployer).id}
          assert_redirected_to user
        end
        user.reload.external_id.must_equal users(:deployer).external_id
      end
    end
  end
end

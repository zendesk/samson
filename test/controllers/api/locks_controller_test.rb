# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Api::LocksController do
  as_a_deployer do
    before { @request_format = :json }
    unauthorized :get, :index
    unauthorized :post, :create # TODO: should allow to create a stage lock as a project deployer
    unauthorized :delete, :destroy, id: 1
  end

  as_a_admin do
    describe '#index' do
      it "renders" do
        Lock.create!(user: users(:admin))

        get :index, format: :json

        assert_response :success
        data = JSON.parse(response.body)
        data.keys.must_equal ['locks']
        data['locks'].first.keys.sort.must_equal [
          "created_at", "id", "resource_id", "resource_type", "user_id", "warning"
        ]
      end
    end

    describe "#create" do
      it "creates" do
        assert_difference "Lock.count", +1 do
          post :create, params: {lock: {description: "foo"}}, format: :json
        end
        assert_response :success
      end
    end

    describe "#destroy" do
      it "unlocks" do
        lock = Lock.create!(user: users(:admin))
        assert_difference "Lock.count", -1 do
          delete :destroy, params: {id: lock.id}, format: :json
        end
        assert_response :success
      end
    end
  end
end

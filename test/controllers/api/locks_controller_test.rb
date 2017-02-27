# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Api::LocksController do
  as_a_deployer do
    before { @request_format = :json }
    unauthorized :get, :index
    unauthorized :post, :create # TODO: should allow to create a stage lock as a project deployer
    unauthorized :delete, :destroy, id: 1
    unauthorized :delete, :destroy_via_resource
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

    describe "#destroy_via_resource" do
      before { Lock.create!(user: users(:admin)) }

      it "unlocks global" do
        assert_difference "Lock.count", -1 do
          delete :destroy_via_resource,
            params: {resource_id: nil, resource_type: nil},
            format: :json
        end
        assert_response :success
      end

      it "unlocks resource" do
        stage = stages(:test_staging)
        Lock.create!(user: users(:admin), resource: stage)
        assert_difference "Lock.count", -1 do
          delete :destroy_via_resource,
            params: {resource_id: stage.id, resource_type: 'Stage'},
            format: :json
        end
        assert_response :success
      end

      it "fails with unfound lock" do
        assert_raises ActiveRecord::RecordNotFound do
          delete :destroy_via_resource,
            params: {resource_id: 333223, resource_type: 'Stage'},
            format: :json
        end
      end

      it "fails without parameters" do
        delete :destroy_via_resource, format: :json
        assert_response :bad_request
        JSON.parse(response.body).must_equal "error" => {"resource_id" => ["is required"]}
      end
    end
  end
end

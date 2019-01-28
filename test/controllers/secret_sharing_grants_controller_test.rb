# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SecretSharingGrantsController do
  let(:project) { projects(:test) }
  let!(:grant) { SecretSharingGrant.create!(project: project, key: "foobar") }

  as_a :viewer do
    describe "#index" do
      it "renders" do
        get :index
        assert_response :success
        assigns(:secret_sharing_grants).size.must_equal 1
      end

      it "can filter" do
        get :index, params: {search: {key: 'nope'}}
        assert_response :success
        assigns(:secret_sharing_grants).size.must_equal 0
      end

      it "ignores blank query" do
        get :index, params: {search: {key: ''}}
        assert_response :success
        assigns(:secret_sharing_grants).size.must_equal 1
      end
    end

    describe "#show" do
      it "renders" do
        get :show, params: {id: grant.id}
        assert_response :success
      end
    end
  end

  as_a :deployer do
    unauthorized :get, :new
    unauthorized :post, :create
    unauthorized :delete, :destroy, id: 1
  end

  as_a :admin do
    describe "#new" do
      it "renders" do
        get :new
        assert_response :success
      end

      it "prefills" do
        create_secret 'production/global/pod2/doobar' # key must exist and be shared
        get :new, params: {secret_sharing_grant: {key: "doobar"}}
        assert_response :success
        response.body.must_include 'selected="selected" value="doobar"'
      end
    end

    describe "#create" do
      let(:params) { {secret_sharing_grant: {key: "doobar", project_id: project.id}, redirect_to: "/foo"} }

      it "creates" do
        assert_difference "SecretSharingGrant.count", +1 do
          post :create, params: params
          assert_redirected_to "/foo"
        end
      end

      it "renders on error" do
        refute_difference "SecretSharingGrant.count", +1 do
          params[:secret_sharing_grant][:key] = grant.key # duplciate
          post :create, params: params
          assert_template :new
        end
      end
    end

    describe "#destroy" do
      it "destroys" do
        assert_difference "SecretSharingGrant.count", -1 do
          delete :destroy, params: {id: grant.id}
          assert_redirected_to secret_sharing_grants_path
        end
      end
    end
  end
end

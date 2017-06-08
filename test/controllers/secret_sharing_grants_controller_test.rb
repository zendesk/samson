# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SecretSharingGrantsController do
  let(:project) { projects(:test) }
  let!(:grant) { SecretSharingGrant.create!(project: project, key: "foobar") }

  as_a_viewer do
    describe "#index" do
      it "renders" do
        get :index
        assert_response :success
      end
    end

    describe "#show" do
      it "renders" do
        get :show, params: {id: grant.id}
        assert_response :success
      end
    end
  end

  as_a_deployer do
    unauthorized :get, :new
    unauthorized :post, :create
    unauthorized :delete, :destroy, id: 1
  end

  as_an_admin do
    describe "#new" do
      it "renders" do
        get :new
        assert_response :success
      end

      it "prefills" do
        get :new, params: {secret_sharing_grant: {key: "doobar"} }
        assert_response :success
        response.body.must_include 'value="doobar"'
      end
    end

    describe "#create" do
      let(:params) { {secret_sharing_grant: {key: "doobar", project_id: project.id}, redirect_to: "/foo" } }

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

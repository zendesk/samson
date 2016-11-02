# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe AccessTokensController do
  as_a_viewer do
    let(:application) { Doorkeeper::Application.create!(name: 'Foobar', redirect_uri: 'http://example.com') }

    describe "#index" do
      let!(:token) { Doorkeeper::AccessToken.create!(application: application, resource_owner_id: user.id) }
      let!(:other_token) { Doorkeeper::AccessToken.create!(application: application, resource_owner_id: 123) }

      it "lists my tokens" do
        get :index
        assert_response :success
        assigns[:access_tokens].must_equal [token]
      end
    end

    describe "#new" do
      it "prefills with default scope so users does not create useless tokens" do
        get :new
        assert_response :success
        assigns[:access_token].scopes.to_a.must_equal ['default']
      end

      it "ensures the personal token exists" do
        get :new
        Doorkeeper::Application.pluck(:name).must_equal ["Personal Access Token"]
      end

      it "does not create multiple personal tokens" do
        get :new
        get :new
        Doorkeeper::Application.pluck(:name).must_equal ["Personal Access Token"]
      end
    end

    describe "#create" do
      it "creates a token for the current user" do
        assert_difference 'Doorkeeper::AccessToken.count', +1 do
          post :create, params: {
            doorkeeper_access_token: {description: 'D', scopes: 'locks, projects', application_id: application.id}
          }
          assert_redirected_to '/access_tokens'
        end
        token = Doorkeeper::AccessToken.last
        token.resource_owner_id.must_equal user.id # scoped to current user
        flash[:notice].must_include token.token # user was able to copy the token
      end
    end

    describe "#destroy" do
      it "destroys" do
        token = Doorkeeper::AccessToken.create!(application: application, resource_owner_id: user.id)
        assert_difference 'Doorkeeper::AccessToken.count', -1 do
          delete :destroy, params: {id: token.id}
        end
        assert_redirected_to '/access_tokens'
      end

      it "does not destroy other peoples tokens" do
        token = Doorkeeper::AccessToken.create!(application: application, resource_owner_id: 123)
        refute_difference 'Doorkeeper::AccessToken.count', -1 do
          assert_raises ActiveRecord::RecordNotFound do
            delete :destroy, params: {id: token.id}
          end
        end
      end
    end
  end
end

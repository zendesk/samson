# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe AccessTokensController do
  def create(format: :html, **attributes)
    post :create, params: {
      doorkeeper_access_token: {
        description: 'D',
        scopes: 'locks, projects',
        application_id: application.id,
        resource_owner_id: user.id
      }.merge(attributes),
      format: format
    }
  end

  let(:application) { Doorkeeper::Application.create!(name: 'Foobar', redirect_uri: 'http://example.com') }
  let(:json) { JSON.parse(response.body) }

  unauthorized :post, :create

  as_a :viewer do
    describe "#index" do
      let!(:token) { Doorkeeper::AccessToken.create!(application: application, resource_owner_id: user.id) }
      let!(:other_token) { Doorkeeper::AccessToken.create!(application: application, resource_owner_id: 123) }

      it "lists my tokens" do
        get :index
        assert_response :success
        assigns[:access_tokens].must_equal [token]
      end

      it "renders json" do
        get :index, format: :json
        assert_response :success
        access_token_keys = json.fetch("access_tokens").fetch(0).keys
        access_token_keys.wont_include "token"
        access_token_keys.wont_include "refresh_token"
      end
    end

    describe "#new" do
      it "prefills with default scope so users does not create useless tokens" do
        get :new
        assert_response :success
        assigns[:access_token].scopes.to_a.must_equal ['default']
      end

      it "ensures the personal application exists" do
        get :new
        Doorkeeper::Application.pluck(:name).must_equal ["Personal Access Token"]
      end

      it "does not create multiple personal application" do
        get :new
        get :new
        Doorkeeper::Application.pluck(:name).must_equal ["Personal Access Token"]
      end
    end

    describe "#create" do
      it "creates a token for the current user" do
        assert_difference 'Doorkeeper::AccessToken.count', +1 do
          create
          assert_redirected_to '/access_tokens'
        end
        token = Doorkeeper::AccessToken.last
        token.resource_owner_id.must_equal user.id # scoped to current user
        flash[:notice].must_include token.token # user was able to copy the token
      end

      it "cannot create for another user" do
        refute_difference 'Doorkeeper::AccessToken.count' do
          create resource_owner_id: users(:admin).id
          assert_response :unauthorized
        end
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

  as_a :super_admin do
    describe "#create" do
      it "can create for another user and returns where they came from" do
        assert_difference 'Doorkeeper::AccessToken.count', +1 do
          create resource_owner_id: users(:admin).id
          assert_redirected_to "/users/#{users(:admin).id}"
        end
      end

      it "can create for another user via json" do
        create resource_owner_id: users(:admin).id, format: :json
        assert_response :success
        access_token_keys = json.fetch("access_token").keys
        access_token_keys.must_include "token"
        access_token_keys.must_include "refresh_token"
      end
    end

    describe "#destroy" do
      it "destroys other peoples tokens" do
        other = users(:admin)
        token = Doorkeeper::AccessToken.create!(application: application, resource_owner_id: other.id)
        assert_difference 'Doorkeeper::AccessToken.count', -1 do
          delete :destroy, params: {id: token.id, doorkeeper_access_token: {resource_owner_id: other.id}}
        end
        assert_redirected_to "/users/#{other.id}"
      end
    end
  end
end

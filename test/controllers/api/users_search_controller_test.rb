# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Api::UsersSearchController do
  oauth_setup!

  before { @request_format = :json }

  as_an_admin do
    unauthorized :get, :index, params: {email: "no-matter@example.com"}, format: :json
  end

  as_a_super_admin do
    describe "#create" do
      it "returns 404" do
        get :index, params: {email: 'unknown@example.com'}, format: :json

        data = JSON.parse(response.body)
        assert_response :not_found
        assert_equal data, {}
      end

      it "returns a match" do
        get :index, params: {email: users(:admin).email}, format: :json

        data = JSON.parse(response.body)
        assert_response :success
        assert_equal data, "user" => {
          "id" => 135138680, "name" => "Admin", "email" => "admin@example.com",
          "role_id" => 2,
          "gravatar_url" => "https://www.gravatar.com/avatar/e64c7d89f26bd1972efa854d13d7dd61",
          "time_format" => "relative"
        }
      end
    end
  end
end

# frozen_string_literal: true
require_relative '../../../test_helper'

SingleCov.covered!

# needs Integration at the end for minitest-spec-rails
describe 'Warden::Strategies::DoorkeeperStrategy Integration' do
  def perform_get(authorization)
    get path, headers: {HTTP_AUTHORIZATION: authorization}
  end

  let(:path) { "/api/deploys/active_count.json".dup }
  let!(:user) { users(:admin) }
  let(:token) { Doorkeeper::AccessToken.create!(resource_owner_id: user.id, scopes: 'default') }
  let!(:valid_header) { "Bearer #{token.token}" }

  it "logs the user in" do
    perform_get valid_header
    assert_response :success, response.body
  end

  it "does not set a session since oauth requests are not suppoed to log in a browser" do
    perform_get valid_header
    response.headers['Set-Cookie'].must_be_nil
  end

  it "does not check and fails without header" do
    assert_sql_queries(0) { perform_get nil }
    assert_response :unauthorized
  end

  it "checks and fails with invalid header" do
    assert_sql_queries(1) { perform_get(valid_header + Base64.encode64('foo')) }
    assert_response :unauthorized
  end

  it "checks and fails with unfound user" do
    user.delete
    assert_sql_queries(3) { perform_get(valid_header) } # FYI queries are: find token, revoke token, find user
    assert_response :unauthorized
  end

  it "checks and fails with missing scope access" do
    token.update_column(:scopes, 'foobar')
    assert_sql_queries(2) { perform_get(valid_header) } # FYI queries are: find token, revoke token
    assert_response :unauthorized
  end

  describe "when accessing web-ui" do
    let(:path) { "/profile" }

    before { stub_request(:get, "https://status.github.com/api/status.json").to_return(body: "{}") }

    it "checks and fails when using api token" do
      perform_get(valid_header)
      assert_response :unauthorized
    end

    it "logs the user in when using web-ui token" do
      token.update_column(:scopes, "web-ui")
      perform_get(valid_header)
      assert_response :success, response.body
    end
  end

  it "checks and fails with expired token" do
    token.update_attributes(expires_in: 1, created_at: 1.day.ago)
    assert_sql_queries(2) { perform_get(valid_header) } # FYI queries are: find token, revoke token
    assert_response :unauthorized
  end

  it "does not check and fails with non matching header" do
    assert_sql_queries(0) { perform_get "oops" + valid_header }
    assert_response :unauthorized
  end

  describe "last_used_at" do
    it "tracks when previously unset" do
      perform_get valid_header
      token.reload.last_used_at.must_be :>, 2.seconds.ago
    end

    it "does not update when recent to avoid db overhead" do
      old = 10.seconds.ago
      token.update_column(:last_used_at, old)
      perform_get valid_header
      token.reload.last_used_at.to_s.must_equal old.to_s
    end

    it "updates when old" do
      old = 1.hour.ago
      token.update_column(:last_used_at, old)
      perform_get valid_header
      token.reload.last_used_at.must_be :>, 2.seconds.ago
    end
  end
end

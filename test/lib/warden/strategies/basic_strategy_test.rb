# frozen_string_literal: true
require_relative '../../../test_helper'

SingleCov.covered!

# needs Integration at the end for minitest-spec-rails
describe 'Warden::Strategies::BasicStrategy Integration' do
  def perform_get(authorization)
    get "/", headers: {HTTP_AUTHORIZATION: authorization}
  end

  before do
    # UI wants to show github status
    stub_request(:get, "#{Rails.application.config.samson.github.status_url}/api/status.json").to_timeout
  end

  let!(:user) { users(:admin) }
  let(:valid_header) { "Basic #{Base64.encode64(user.email + ':' + user.token).strip}" }

  it "logs the user in" do
    perform_get valid_header
    assert_response :success
  end

  it "does not set a session since basic auth requests are not suppoed log in a browser" do
    perform_get valid_header
    response.headers['Set-Cookie'].must_be_nil
  end

  it "does not check and fails without header" do
    assert_sql_queries(0) { perform_get nil }
    assert_response :redirect
  end

  it "checks and fails with invalid header" do
    assert_sql_queries(1) { perform_get(valid_header + Base64.encode64('foo')) }
    assert_response :redirect
  end

  it "does not check and fails with non matching header" do
    assert_sql_queries(0) { perform_get "oops" + valid_header }
    assert_response :redirect
  end
end

# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe 'DoorkeeperBaseController Integration' do
  it "cannot access as admin" do
    login_as users(:admin)
    get '/oauth/applications'
    assert_redirected_to '/login'
  end

  it "can access as super-admin" do
    stub_request(:get, "https://status.github.com/api/status.json").to_return(body: "{}")
    login_as users(:super_admin)
    get '/oauth/applications'
    assert_response :success
  end
end

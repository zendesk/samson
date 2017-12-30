# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe 'DoorkeeperBaseController Integration' do
  it "cannot access as admin" do
    login_as users(:admin)
    get '/oauth/applications'
    assert_redirected_to '/login?redirect_to=%2Foauth%2Fapplications'
  end

  it "can access as super-admin" do
    login_as users(:super_admin)
    get '/oauth/applications'
    assert_response :success
  end
end

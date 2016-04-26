require_relative '../../test_helper'

SingleCov.covered!

describe "Authorization included in controller" do
  class AuthorizationTestController < ApplicationController
    include Authorization
    include CurrentUser

    def super_admin_action
      authorize_super_admin!
      head :ok
    end

    def admin_action
      authorize_admin!
      head :ok
    end

    def deployer_action
      authorize_deployer!
      head :ok
    end

    def unauthorized_action
      unauthorized!
    end
  end

  tests AuthorizationTestController
  use_test_routes

  def self.authorized(method, action, params)
    it "is authorized to #{method} #{action}" do
      send method, action, params
      refute_unauthorized
    end
  end

  as_a_viewer do
    unauthorized :get, :deployer_action, test_route: true
    unauthorized :get, :admin_action, test_route: true
    unauthorized :get, :super_admin_action, test_route: true
  end

  as_a_deployer do
    authorized :get, :deployer_action, test_route: true
    unauthorized :get, :admin_action, test_route: true
    unauthorized :get, :super_admin_action, test_route: true
  end

  as_a_admin do
    authorized :get, :deployer_action, test_route: true
    authorized :get, :admin_action, test_route: true
    unauthorized :get, :super_admin_action, test_route: true
  end

  as_a_super_admin do
    authorized :get, :deployer_action, test_route: true
    authorized :get, :admin_action, test_route: true
    authorized :get, :super_admin_action, test_route: true
  end

  as_a_viewer do
    it "logs unautorized so we can see it in test output for easy debugging" do
      Rails.logger.expects(:warn)
      get :unauthorized_action, test_route: true
      assert_unauthorized
    end
  end
end

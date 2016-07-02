class Api::V1::ApplicationController < ActionController::Base
  include CurrentUser

  def warden_strategies
    [:basic]
  end
end

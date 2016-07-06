class Api::V1::ApplicationController < ActionController::Base
  include CurrentUser

  private

  def warden_strategies
    [:basic]
  end
end

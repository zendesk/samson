# frozen_string_literal: true
require 'doorkeeper_auth'

class Api::BaseController < ApplicationController
  skip_before_action :verify_authenticity_token

  include DoorkeeperAuth

  api_accessible! true

  def paginate(scope)
    if scope.is_a?(Array)
      Kaminari.paginate_array(scope).page(page).per(1000)
    else
      scope.page(page)
    end
  end

  def page
    params.fetch(:page, 1)
  end
end

class Api::DeploysController < Api::BaseController
  def active_count
    render json: Deploy.active.count
  end
end

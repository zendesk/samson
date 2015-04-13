class FlowdockController < ApplicationController
  before_action :find_deploy, only: [:notify]

  rescue_from ActiveRecord::RecordNotFound do
    render status: 404, json: { message: 'Could not find deploy!' }
  end

  def users
    users = Rails.cache.fetch(:flowdock_users, expires_in: 5.minutes, race_condition_ttl: 5) do
      flowdock_service.users
    end
    render json: { users: users }
  end

  def notify
    FlowdockNotification.new(@deploy).buddy_request(params[:message])
    render json: { message: 'Successfully sent a buddy request to the flows!' }
  end

  private

  def find_deploy
    @deploy = Deploy.find(params[:deploy_id])
  end

  def flowdock_service
    SamsonFlowdock::FlowdockService.new(@deploy)
  end
end

require 'flowdock'

class FlowdockController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound do |error|
    render status: 404, json: { message: error.message }
  end

  def users
    users = Rails.cache.fetch(:flowdock_users, expires_in: 5.minutes, race_condition_ttl: 5) do
      flowdock_service.users
    end
    render json: { users: users }
  rescue Flowdock::InvalidParameterError
    Rails.logger.error('Could not fetch flowdock users! Please set the FLOWDOCK_API_TOKEN env variable')
    render json: { error: 'Could not get the users from flowdock' }, status: 404
  end

  def notify
    @deploy = Deploy.find(params[:deploy_id])
    FlowdockNotification.new(@deploy).buddy_request(params[:message])
    render json: { message: 'Successfully sent a buddy request to the flows!' }
  end

  private

  def flowdock_service
    SamsonFlowdock::FlowdockService.new(@deploy)
  end
end

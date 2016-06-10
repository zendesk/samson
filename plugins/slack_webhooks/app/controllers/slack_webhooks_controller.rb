require 'slack-ruby-client'

class SlackWebhooksController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound do |error|
    render status: 404, json: { message: error.message }
  end

  def users
    users = Rails.cache.fetch(:slack_users, expires_in: 5.minutes, race_condition_ttl: 5) do
      slack_webhooks_service.users
    end
    render json: { users: users }
  rescue Slack::Web::Api::Error => e
    Rails.logger.error('Could not fetch Slack users! Please set the SLACK_API_TOKEN env variable')
    render json: { error: "Could not get the users from Slack: #{e.message}" }, status: 404
  end

  def notify
    @deploy = Deploy.find(params[:deploy_id])
    SlackWebhookNotification.new(@deploy, :for_buddy).deliver(params[:message])
    render json: { message: 'Successfully sent a buddy request to the channels!' }
  end

  private

  def slack_webhooks_service
    SamsonSlackWebhooks::SlackWebhooksService.new(@deploy)
  end
end

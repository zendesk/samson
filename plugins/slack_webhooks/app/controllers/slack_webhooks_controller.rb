require 'slack-ruby-client'

class SlackWebhooksController < ApplicationController
  def buddy_request
    @deploy = Deploy.find(params.require(:deploy_id))
    SlackWebhookNotification.new(deploy: @deploy, deploy_phase: :for_buddy).deliver(message: params.require(:message))
    head :ok
  end
end

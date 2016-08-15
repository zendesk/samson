# frozen_string_literal: true
class SlackWebhooksController < ApplicationController
  def buddy_request
    @deploy = Deploy.find(params.require(:deploy_id))
    SlackWebhookNotification.new(@deploy).buddy_request(params.require(:message))
    head :ok
  end
end

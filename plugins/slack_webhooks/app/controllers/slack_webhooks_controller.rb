# frozen_string_literal: true
class SlackWebhooksController < ApplicationController
  def buddy_request
    deploy = Deploy.find(params.require(:deploy_id))
    webhooks = deploy.stage.slack_webhooks.select { |w| w.deliver_for?(:buddy_box, deploy) }
    SlackWebhookNotification.new(deploy, webhooks).deliver(:buddy_box, message: params.require(:message))
    head :ok
  end
end

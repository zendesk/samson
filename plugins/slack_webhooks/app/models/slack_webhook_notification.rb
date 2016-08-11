# frozen_string_literal: true
class SlackWebhookNotification
  def initialize(deploy)
    @deploy = deploy
    @stage = deploy.stage
    @project = @stage.project
    @user = @deploy.user
  end

  # deploy_phase is either :before_deploy or :after_deploy
  def deliver(deploy_phase)
    _deliver(deploy_phase: deploy_phase, message: content)
  end

  def buddy_request(message)
    _deliver(deploy_phase: :for_buddy, message: message)
  end

  def default_buddy_request_message
    project = @deploy.project
    # https://api.slack.com/docs/message-formatting
    ":pray: <!here> _#{@deploy.user.name}_ is requesting approval" \
      " to deploy #{project.name} *#{@deploy.reference}* to #{@deploy.stage.name}.\n"\
      "Review this deploy: #{Rails.application.routes.url_helpers.project_deploy_url(project, @deploy)}"
  end

  private

  def content
    subject = "[#{@project.name}] #{@deploy.summary}"
    @content ||= SlackWebhookNotificationRenderer.render(@deploy, subject)
  end

  def _deliver(deploy_phase:, message:)
    @stage.slack_webhooks.each do |webhook|
      if webhook.public_send(deploy_phase)
        SamsonSlackWebhooks::SlackWebhooksService.new.deliver_message_via_webhook(webhook: webhook, message: message)
      end
    end
  end
end

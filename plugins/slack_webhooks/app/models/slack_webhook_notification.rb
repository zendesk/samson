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

  private

  def content
    subject = "[#{@project.name}] #{@deploy.summary}"
    @content ||= SlackWebhookNotificationRenderer.render(@deploy, subject)
  end

  def _deliver(deploy_phase:, message:)
    @stage.slack_webhooks.each do |webhook|
      if webhook.public_send(deploy_phase)
        _deliver_for_one_webhook(webhook: webhook, message: message)
      end
    end
  end

  def _deliver_for_one_webhook(webhook:, message:)
    payload = { text: message, username: 'samson-bot' }
    payload[:channel] = webhook.channel unless webhook.channel.blank?

    Faraday.post(webhook.webhook_url, payload: payload.to_json)
  rescue Faraday::ClientError => e
    Rails.logger.error("Could not deliver slack message: #{e.message}")
  end
end

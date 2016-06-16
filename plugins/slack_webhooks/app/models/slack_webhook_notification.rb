class SlackWebhookNotification
  def initialize(deploy:, deploy_phase:)
    @deploy = deploy
    @deploy_phase = deploy_phase
    @stage = deploy.stage
    @project = @stage.project
    @user = @deploy.user
  end

  def deliver(message: content)
    @stage.slack_webhooks.each do |webhook|
      if webhook.public_send(@deploy_phase)
        _deliver(webhook: webhook, message: message)
      end
    end
  end

  private

  def content
    subject = "[#{@project.name}] #{@deploy.summary}"
    @content ||= SlackWebhookNotificationRenderer.render(@deploy, subject)
  end

  def _deliver(webhook:, message:)
    payload = { text: message, username: 'samson-bot' }
    payload[:channel] = webhook.channel unless webhook.channel.blank?

    Faraday.post(webhook.webhook_url, payload: payload.to_json)
  rescue Faraday::ClientError => e
    Rails.logger.error("Could not deliver slack message: #{e.message}")
  end
end

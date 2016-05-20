class SlackWebhookNotification
  def initialize(deploy)
    @deploy = deploy
    @stage = deploy.stage
    @project = @stage.project
    @user = @deploy.user
  end

  def deliver
    @stage.slack_webhooks.each do |webhook|
      _deliver(webhook)
    end
  end

  private

  def content
    subject = "[#{@project.name}] #{@deploy.summary}"
    @content ||= SlackWebhookNotificationRenderer.render(@deploy, subject)
  end

  def _deliver(webhook)
    payload = { text: content, username: 'samson-bot' }
    payload[:channel] = webhook.channel unless webhook.channel.blank?

    Faraday.post(webhook.webhook_url, payload: payload.to_json)
  rescue Faraday::ClientError => e
    Rails.logger.error("Could not deliver slack message: #{e.message}")
  end
end

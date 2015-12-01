class SlackNotification
  def initialize(deploy)
    @deploy = deploy
    @stage = deploy.stage
    @project = @stage.project
    @user = @deploy.user
    @webhook = @stage.slack_webhooks.first
  end


  def deliver
    payload = {text: content, username: "samson-bot"}
    payload.merge!(channel: @webhook.channel) unless @webhook.channel.blank?

    Faraday.post(@webhook.webhook_url, payload: payload.to_json)
  rescue Faraday::ClientError => e
    Rails.logger.error("Could not deliver slack message: #{e.message}")
  end

  private

  def content
    subject = "[#{@project.name}] #{@deploy.summary}"
    @content ||= SlackNotificationRenderer.render(@deploy, subject)
  end

end

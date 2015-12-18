class SlackNotification
  def initialize(deploy)
    @deploy = deploy
    @stage = deploy.stage
    @project = @stage.project
    @user = @deploy.user
  end

  def deliver
    Slack.chat_postMessage(
      token: ENV['SLACK_TOKEN'],
      channel: @stage.slack_channels.first.channel_id,
      text: content)

  rescue Slack::Error => e
    Rails.logger.error("Could not deliver slack message: #{e.message}")
  end

  private

  def content
    subject = "[#{@project.name}] #{@deploy.summary}"
    @content ||= SlackNotificationRenderer.render(@deploy, subject)
  end

end

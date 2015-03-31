class SlackNotification
  def initialize(stage, deploy)
    @stage, @deploy = stage, deploy
    @project = @stage.project
    @user = @deploy.user
  end

  def deliver
    Slack.chat_postMessage(
      token: ENV['SLACK_TOKEN'],
      channel: @stage.slack_channels.first.channel_id,
      text: content,
      parse: "full")

  rescue Slack::Error
  end

  private

  def content
    subject = "[#{@project.name}] #{@deploy.summary}"
    @content ||= SlackNotificationRenderer.render(@deploy, subject)
  end

  def url_helpers
    Rails.application.routes.url_helpers
  end
end

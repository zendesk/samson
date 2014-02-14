require 'flowdock'

class FlowdockNotification
  def initialize(stage, deploy)
    @stage, @deploy = stage, deploy
    @project = @stage.project
    @user = @deploy.user
  end

  def deliver
    subject = "[#{@project.name}] #{@deploy.summary}"
    url = url_helpers.project_deploy_url(@project, @deploy)

    flow.push_to_team_inbox(
      subject: subject,
      content: content,
      tags: ["deploy", @stage.name.downcase],
      link: url
    )
  rescue Flowdock::Flow::ApiError
    # Invalid token or something.
  end

  private

  def flow
    @flow ||= Flowdock::Flow.new(
      api_token: @stage.flowdock_tokens,
      source: "samson",
      from: { name: @user.name, address: @user.email }
    )
  end

  def content
    @content ||= FlowdockNotificationRenderer.render(@deploy)
  end

  def url_helpers
    Rails.application.routes.url_helpers
  end
end

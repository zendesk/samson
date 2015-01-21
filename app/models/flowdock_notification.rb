require 'flowdock'

class FlowdockNotification
  def initialize(stage, deploy)
    @stage, @deploy = stage, deploy
    @project = @stage.project
    @user = @deploy.user
  end

  def buddy_request(message)
    buddy_request_content = message.nil? || message.empty? ? default_notification_content : message
    chat_flow = Flowdock::Flow.new(api_token: @stage.flowdock_tokens, external_user_name: 'Samson')
    chat_flow.push_to_chat(:content => buddy_request_content, :tags => ["buddy-request"])
  end

  def default_notification_content
    ':pray: ' + @user.name + ' is requesting approval for deploy ' + url_helpers.project_deploy_url(@project, @deploy)
  end

  def buddy_request_completed(buddy, approved = true)
    chat_flow = Flowdock::Flow.new(
      :api_token => @stage.flowdock_tokens,
      :external_user_name => 'Samson'
    )

    text = @user.name
    if @user == buddy
      text += " bypassed"
    else
      text +=  " " + buddy.name + (approved ? " approved" : " stopped")
    end

    buddy_request_content = text + " deploy " + url_helpers.project_deploy_url(@project, @deploy)
    chat_flow.push_to_chat(:content => buddy_request_content, :tags => ["buddy-request", "completed"])
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

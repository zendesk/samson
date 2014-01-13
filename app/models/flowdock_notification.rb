require 'flowdock'

class FlowdockNotification
  def initialize(stage, deploy)
    @stage, @deploy = stage, deploy
    @project = @stage.project
  end

  def deliver
    subject = "[#{@project.name}] #{@deploy.summary}"
    flow.push_to_team_inbox(subject: subject, content: @deploy.summary)
  rescue Flowdock::Flow::ApiError
    # Invalid token or something.
  end

  private

  def api_tokens
    @stage.flowdock_tokens
  end

  def flow
    @flow ||= Flowdock::Flow.new(
      api_token: api_tokens,
      source: "pusher",
      from: { name: "Pusher", address: "pusher@example.com" }
    )
  end
end

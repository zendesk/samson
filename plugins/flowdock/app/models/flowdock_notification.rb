require 'flowdock'

class FlowdockNotification
  delegate :project, :stage, :user, to: :@deploy

  def initialize(deploy)
    @deploy = deploy
  end

  def buddy_request(message)
    flowdock_service.notify_chat(message, ['buddy-request'])
  end

  def buddy_request_completed(buddy, approved = true)
    buddy_request_content = buddy_request_completed_message(approved, buddy)
    flowdock_service.notify_chat(buddy_request_content, %w(buddy-request completed))
  end

  def deliver
    subject = "[#{project.name}] #{@deploy.summary}"
    flowdock_service.notify_inbox(subject, content)
  rescue Flowdock::ApiError => e
    Rails.logger.error("Could not deliver flowdock message: #{e.message}")
  end

  private

  def flow
    @flow ||= Flowdock::Flow.new(
      api_token: project.flowdock_tokens,
      source: "samson",
      from: { name: user.name, address: user.email }
    )
  end

  def buddy_request_completed_message(approved, buddy)
    if user == buddy
       "#{user.name} bypassed deploy #{@deploy.url}"
     else
       "#{user.name} #{buddy.name} #{approved ? 'approved' : 'stopped' } deploy #{@deploy.url}"
     end
  end

  def content
    @content ||= FlowdockNotificationRenderer.render(@deploy)
  end

  def flowdock_service
    @flowdock_service ||= SamsonFlowdock::FlowdockService.new(@deploy)
  end
end

# frozen_string_literal: true
require 'flowdock'

class FlowdockNotification
  delegate :project, :stage, :user, to: :@deploy
  delegate :project_deploy_url, to: 'Rails.application.routes.url_helpers'

  def initialize(deploy)
    @deploy = deploy
  end

  def buddy_request(message)
    flowdock_service.notify_chat(message, ['buddy-request'])
  end

  # TODO: delete this dead code
  def buddy_request_completed(buddy, **args)
    buddy_request_content = buddy_request_completed_message(buddy, **args)
    flowdock_service.notify_chat(buddy_request_content, ['buddy-request', 'completed'])
  end

  def deliver
    subject = "[#{project.name}] #{@deploy.summary}"
    flowdock_service.notify_inbox(subject, content, deploy_url)
  rescue Flowdock::ApiError => e
    Rails.logger.error("Could not deliver flowdock message: #{e.message}")
    Samson::ErrorNotifier.notify(e, error_message: 'Could not deliver flowdock message')
  end

  def default_buddy_request_message
    project = @deploy.project
    ":ship: @team #{@deploy.user.name} is requesting approval" \
      " to deploy #{project.name} **#{@deploy.reference}** to production."\
      " [Review this deploy](#{project_deploy_url(project, @deploy)})."
  end

  private

  def buddy_request_completed_message(buddy, approved:)
    if user == buddy
      "#{user.name} bypassed deploy #{deploy_url}"
    else
      "#{user.name} #{buddy.name} #{approved ? 'approved' : 'cancelled'} deploy #{deploy_url}"
    end
  end

  def content
    @content ||= FlowdockNotificationRenderer.render(@deploy)
  end

  def flowdock_service
    @flowdock_service ||= SamsonFlowdock::FlowdockService.new(@deploy)
  end

  def deploy_url
    project_deploy_url(@deploy.project, @deploy)
  end
end

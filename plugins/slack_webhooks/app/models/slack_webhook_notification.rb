# frozen_string_literal: true
class SlackWebhookNotification
  def initialize(deploy)
    @deploy = deploy
    @stage = deploy.stage
    @project = @stage.project
    @user = @deploy.user
  end

  # deploy_phase is either :before_deploy or :after_deploy
  def deliver(deploy_phase)
    _deliver(deploy_phase: deploy_phase, message: content)
  end

  def buddy_request(message)
    _deliver(deploy_phase: :for_buddy, message: message, attachments: [pr_and_risk_attachment])
  end

  def default_buddy_request_message
    project = @deploy.project
    # https://api.slack.com/docs/message-formatting
    ":pray: <!here> _#{@deploy.user.name}_ is requesting approval to deploy " \
      "<#{Rails.application.routes.url_helpers.project_deploy_url(project, @deploy)}|" \
      "#{project.name} *#{@deploy.reference}* to #{@deploy.stage.name}>."
  end

  private

  def content
    subject = "[#{@project.name}] #{@deploy.summary}"
    @content ||= SlackWebhookNotificationRenderer.render(@deploy, subject)
  end

  def _deliver(deploy_phase:, message:, attachments: nil)
    @stage.slack_webhooks.each do |webhook|
      next unless webhook.deliver_for?(deploy_phase, @deploy)
      SamsonSlackWebhooks::SlackWebhooksService.new.deliver_message_via_webhook(
        webhook: webhook,
        message: message,
        attachments: attachments
      )
    end
  end

  def pr_and_risk_attachment
    {
      fields: [pr_field, risks_field]
    }
  end

  def pr_field
    prs_string = @deploy.changeset.pull_requests.map do |pr|
      "<#{pr.url}|##{pr.number}> - #{pr.title}"
    end.join("\n")
    prs_string = '(no PRs)' if prs_string.empty?
    {
      title: 'PRs',
      value: prs_string,
      short: true
    }
  end

  def risks_field
    risks_string = @deploy.changeset.pull_requests.each_with_object([]) do |pr, result|
      result << "<#{pr.url}|##{pr.number}>:\n#{pr.risks}" if pr.risks
    end.join("\n")
    risks_string = '(no risks)' if risks_string.empty?
    {
      title: 'Risks',
      value: risks_string,
      short: true
    }
  end
end

# frozen_string_literal: true
class SlackWebhookNotification
  def initialize(deploy, webhooks)
    @deploy = deploy
    @stage = deploy.stage
    @project = @stage.project
    @user = @deploy.user
    @webhooks = webhooks
  end

  # phase is:
  # - before_deploy or after_deploy
  # - buddy_request from callback
  # - buddy_box from user manually sending the request with customized message
  def deliver(phase, message: default_buddy_request_message)
    if [:buddy_request, :buddy_box].include?(phase)
      _deliver(message: message, attachments: [pr_and_risk_attachment])
    else # before_deploy or after_deploy
      _deliver(message: deploy_callback_content)
    end
  end

  # shown in the UI so user can modify
  # https://api.slack.com/docs/message-formatting
  def default_buddy_request_message
    project = @deploy.project
    ":ship: <!here> _#{@deploy.user.name}_ is requesting approval to deploy " \
      "<#{Rails.application.routes.url_helpers.project_deploy_url(project, @deploy)}|" \
      "*#{@deploy.reference}* to #{@deploy.stage.unique_name}>."
  end

  private

  def _deliver(message:, attachments: nil)
    @webhooks.each do |webhook|
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

  def deploy_callback_content
    subject = "[#{@project.name}] #{@deploy.summary}"
    lookup_context = ActionView::Base.
      build_lookup_context([File.expand_path('../views/samson_slack_webhooks', __dir__)])
    view = ActionView::Base.with_empty_template_cache.new(lookup_context)
    show_prs = @deploy.pending? || @deploy.running?
    status_emoji =
      case @deploy.status
      when 'pending' then ':stopwatch:'
      when 'running' then ':truck::dash:'
      when 'errored', 'failed', 'cancelled' then ':x:'
      when 'succeeded' then ':white_check_mark:'
      else ''
      end
    locals = {
      deploy: @deploy,
      status_emoji: status_emoji,
      changeset: @deploy.changeset,
      subject: subject,
      show_prs: show_prs
    }
    view.render(template: 'notification', locals: locals).chomp
  end
end

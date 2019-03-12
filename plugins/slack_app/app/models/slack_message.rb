# frozen_string_literal: true
class SlackMessage
  def initialize(deploy)
    @deploy = deploy
  end

  def deliver
    # Only deploys triggered by the slash-command will have a DeployResponseUrl,
    # but we'll get to this point after every deploy completes.
    url = DeployResponseUrl.find_by(deploy_id: @deploy.id)&.response_url
    return unless url.present?

    Faraday.new(url).post do |request|
      request.headers['Content-Type'] = 'application/json'
      request.body = JSON.unparse message_body
    end
  end

  def message_body
    body = if @deploy.waiting_for_buddy?
      waiting_for_buddy_body
    elsif @deploy.failed? || @deploy.errored?
      failed_body
    elsif @deploy.succeeded?
      succeeded_body
    else
      running_body
    end
    body[:response_type] = 'in_channel'
    body
  end

  private

  def waiting_for_buddy_body
    {
      text: title,
      attachments: [{
        text: 'Approve this deploy?',
        callback_id: @deploy.id,
        fields: fields,
        actions: [
          button(':+1: Approve', 'yes')
        ]
      }]
    }
  end

  def running_body
    {
      text: title,
      attachments: [{
        text: "Deploying…",
        fields: fields,
        color: 'warning'
      }]
    }
  end

  def failed_body
    {
      text: ':x: ' + title('failed to deploy'),
    }
  end

  def succeeded_body
    {
      text: ':tada: ' + title('successfully deployed')
    }
  end

  def user_string(user)
    slack_identifier = SlackIdentifier.find_by_user_id(user.id)
    return "<@#{slack_identifier.identifier}>" if slack_identifier.present?
    user.email
  end

  def title(ended = nil)
    str = +"#{user_string(@deploy.user)} "
    connector = 'is'
    if @deploy.buddy
      str << "and #{user_string(@deploy.buddy)} "
      connector = 'are'
    end

    str <<
      if ended
        "#{ended} "
      elsif @deploy.waiting_for_buddy?
        'wants to deploy '
      else
        "#{connector} deploying "
      end

    stage = @deploy.stage
    str << "<#{@deploy.url}|*#{stage.project.name}* to *#{stage.name}*>."
  end

  def fields
    [pr_field, risks_field]
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

  def button(text, value)
    {
      name: value,
      value: value,
      text: text,
      type: 'button',
      confirm: {
        title: 'Are you sure?',
        text: 'Confirm approval of this deployment.',
        ok_text: 'Confirm',
        dismiss_text: 'Never mind'
      }
    }
  end
end

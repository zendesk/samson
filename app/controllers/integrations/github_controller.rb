class Integrations::GithubController < Integrations::BaseController
  cattr_accessor(:github_hook_secret) { ENV['GITHUB_HOOK_SECRET'] }

  HMAC_DIGEST = OpenSSL::Digest.new('sha1')
  ACCEPTED_EVENTS = ['push', 'pull_request.open', 'issue_comment']

  protected

  def deploy?
    valid_signature? && valid_payload?
  end

  def valid_signature?
    hmac = OpenSSL::HMAC.hexdigest(
      HMAC_DIGEST,
      github_hook_secret,
      request.body.tap(&:rewind).read
    )

    Rack::Utils.secure_compare(request.headers['X-Hub-Signature'].to_s, "sha1=#{hmac}")
  end

  def valid_payload?
    webhook_event && ACCEPTED_EVENTS.include?(webhook_event.event_type)
  end

  def commit
    webhook_event.sha
  end

  def branch
    webhook_event.branch
  end

  private

  def webhook_event
    return @webhook_event if defined?(@webhook_event)

    @webhook_event = begin
      case request.headers['X-Github-Event']
      when 'push'
        Changeset::CodePush.new(project.repo_name, params)
      when 'pull_request'
        Changeset::PullRequest.find(project.repo_name, params[:number])
      when 'issue_comment'
        Changeset::IssueComment.new(project.repo_name, params)
      end
    end
  end

  def service_type
    webhook_event && webhook_event.service_type
  end
end

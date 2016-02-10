class Changeset::IssueComment
  attr_reader :repo, :data

  COMMENT_FILTER = /(\[)\s*(samson)\s*(\])/i # [samson]

  def initialize(repo, data)
    @repo = repo
    @body = data['body']
    @data = data['issue']
  end

  def self.changeset_from_webhook(project, params = {})
    comment = params['comment'] && params['comment']['body']
    return unless comment && comment =~ COMMENT_FILTER
    new(project.github_repo, params)
  end

  def sha
    pull_request.sha
  end

  def branch
    pull_request.sha
  end

  def service_type
    'pull_request' # Samson webhook category
  end

  private

  def pull_request
    @pull_request ||= Changeset::PullRequest.find(repo, data['number'])
  end
end

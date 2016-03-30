class Changeset::IssueComment
  attr_reader :repo, :data

  def initialize(repo, data)
    @repo = repo
    @body = data['body']
    @data = data['issue']
  end

  def self.changeset_from_webhook(project, params = {})
    new(project.github_repo, params)
  end

  def self.valid_webhook?(params)
    comment = params['comment'] || {}
    !(comment['body'] =~ Changeset::PullRequest::WEBHOOK_FILTER).nil?
  end

  def sha
    pull_request.sha
  end

  def branch
    pull_request.branch
  end

  def service_type
    'pull_request' # Samson webhook category
  end

  private

  def pull_request
    @pull_request ||= Changeset::PullRequest.find(repo, data['number'])
  end
end

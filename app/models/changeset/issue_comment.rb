class Changeset::IssueComment
  attr_reader :repo, :data

  def initialize(repo, data)
    @repo = repo
    @body = data['body']
    @data = data['issue']
  end

  def self.changeset_from_webhook(project, params = {})
    new(project.repo_name, params)
  end

  def sha
    pull_request.sha
  end

  def branch
    pull_request.sha
  end

  def event_type
    'issue_comment' # Github's event name
  end

  def service_type
    'pull_request' # Samson's webhook category
  end

  private

  def pull_request
    @pull_request ||= Changeset::PullRequest.find(repo, data['number'])
  end
end

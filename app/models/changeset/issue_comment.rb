class Changeset::IssueComment
  attr_reader :repo, :data

  def initialize(repo, data)
    @repo = repo
    @body = data['body']
    @data = data['issue']
  end

  def sha
    pull_request.sha
  end

  def branch
    pull_request.sha
  end

  def event_type
    'issue_comment'
  end

  def service_type
    'pull_request'
  end

  private

  def pull_request
    @pull_request ||= Changeset::PullRequest.find(repo, data['number'])
  end
end

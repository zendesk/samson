# frozen_string_literal: true
class Changeset::IssueComment
  attr_reader :repo, :data, :comment
  VALID_ACTIONS = ['created'].freeze

  def initialize(repo, data)
    @repo = repo
    @body = data['body']
    @comment = data['comment']
    @data = data['issue']
  end

  def self.changeset_from_webhook(project, params = {})
    new(project.github_repo, params)
  end

  def self.valid_webhook?(params)
    return false unless VALID_ACTIONS.include? params.dig('github', 'action')
    params.dig('comment', 'body') =~ Changeset::PullRequest::WEBHOOK_FILTER
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
    pr_data = Rails.cache.fetch(['IssueComment', repo, comment['id']].join("-")) do
      GITHUB.pull_request(repo, data['number'])
    end
    @pull_request ||= Changeset::PullRequest.new(repo, pr_data)
  end
end

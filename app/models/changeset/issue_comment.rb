# frozen_string_literal: true
class Changeset::IssueComment
  attr_reader :repo, :data, :comment

  delegate :sha, :branch, to: :pull_request
  VALID_ACTIONS = ['created'].freeze

  def initialize(repo, data)
    @repo = repo
    @body = data['body']
    @comment = data['comment']
    @data = data['issue']
  end

  def self.changeset_from_webhook(project, payload)
    new(project.repository_path, payload)
  end

  def self.valid_webhook?(payload)
    return false unless VALID_ACTIONS.include? payload['action']
    payload.dig('comment', 'body') =~ Changeset::PullRequest::WEBHOOK_FILTER
  end

  def service_type
    'pull_request' # Samson webhook category
  end

  def message
    nil
  end

  private

  def pull_request
    pr_data = Rails.cache.fetch(['IssueComment', repo, comment['id']].join("-")) do
      GITHUB.pull_request(repo, data['number'])
    end
    @pull_request ||= Changeset::PullRequest.new(repo, pr_data)
  end
end

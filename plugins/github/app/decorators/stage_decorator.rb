# frozen_string_literal: true
Stage.class_eval do
  validate :validate_github_pull_request_comment_variables

  private

  def validate_github_pull_request_comment_variables
    if comment = github_pull_request_comment.presence
      comment % Hash[GithubNotification::SUPPORTED_KEYS.map { |k| [k, ''] }] # Validate no extra keys are supplied
    end
  rescue KeyError, ArgumentError => e
    errors.add(:github_pull_request_comment, e.message)
  end
end

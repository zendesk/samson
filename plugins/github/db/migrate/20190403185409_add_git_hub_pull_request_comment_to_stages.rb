# frozen_string_literal: true
class AddGitHubPullRequestCommentToStages < ActiveRecord::Migration[5.2]
  def change
    add_column :stages, :github_pull_request_comment, :string
  end
end

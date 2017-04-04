# frozen_string_literal: true
class AddGithubConfirmationToStages < ActiveRecord::Migration[4.2]
  def change
    add_column :stages, :update_github_pull_requests, :boolean
  end
end

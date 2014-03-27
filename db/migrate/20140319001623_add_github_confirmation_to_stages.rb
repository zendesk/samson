class AddGithubConfirmationToStages < ActiveRecord::Migration
  def change
    add_column :stages, :update_github_pull_requests, :boolean
  end
end

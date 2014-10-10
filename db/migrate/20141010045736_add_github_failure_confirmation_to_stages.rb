class AddGithubFailureConfirmationToStages < ActiveRecord::Migration
  def change
    add_column :stages, :update_github_pull_requests_on_failure, :boolean
  end
end

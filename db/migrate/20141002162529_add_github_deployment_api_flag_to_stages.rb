class AddGithubDeploymentApiFlagToStages < ActiveRecord::Migration
  def change
    add_column :stages, :use_github_deployment_api, :boolean
  end
end

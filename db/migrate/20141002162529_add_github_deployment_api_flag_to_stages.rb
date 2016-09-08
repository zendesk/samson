# frozen_string_literal: true
class AddGithubDeploymentApiFlagToStages < ActiveRecord::Migration[4.2]
  def change
    add_column :stages, :use_github_deployment_api, :boolean
  end
end

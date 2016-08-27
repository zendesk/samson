# frozen_string_literal: true
class AddDeployToNewPodsToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :include_new_deploy_groups, :boolean
  end
end

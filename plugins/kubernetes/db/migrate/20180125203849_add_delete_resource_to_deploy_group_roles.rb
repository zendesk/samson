# frozen_string_literal: true
class AddDeleteResourceToDeployGroupRoles < ActiveRecord::Migration[5.1]
  def change
    add_column :kubernetes_deploy_group_roles, :delete_resource, :boolean, default: false, null: false
    add_column :kubernetes_release_docs, :delete_resource, :boolean, default: false, null: false
  end
end

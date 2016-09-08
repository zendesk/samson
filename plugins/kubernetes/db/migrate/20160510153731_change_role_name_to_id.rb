# frozen_string_literal: true
# rubocop:disable Metrics/LineLength
class ChangeRoleNameToId < ActiveRecord::Migration[4.2]
  INDEX = "index_kubernetes_deploy_group_roles_on_project_id"

  class KubernetesRole < ActiveRecord::Base
  end

  class KubernetesDeployGroupRole < ActiveRecord::Base
  end

  # change all role names to direct role references or delete the record
  def up
    add_column :kubernetes_deploy_group_roles, :kubernetes_role_id, :integer

    KubernetesDeployGroupRole.find_each do |dgr|
      if role = KubernetesRole.where(project_id: dgr.project_id, name: dgr.name).first
        dgr.update_column(:kubernetes_role_id, role.id)
      else
        dgr.destroy
      end
    end

    change_column_null :kubernetes_deploy_group_roles, :kubernetes_role_id, false
    remove_old_index
    remove_column :kubernetes_deploy_group_roles, :name

    add_index :kubernetes_deploy_group_roles, [:project_id, :deploy_group_id, :kubernetes_role_id], name: INDEX
  end

  def down
    add_column :kubernetes_deploy_group_roles, :name, :string

    KubernetesDeployGroupRole.find_each do |dgr|
      if role = KubernetesRole.where(id: dgr.kubernetes_role_id).first
        dgr.update_column(:name, role.name)
      else
        dgr.destroy
      end
    end

    change_column_null :kubernetes_deploy_group_roles, :name, false
    remove_old_index
    remove_column :kubernetes_deploy_group_roles, :kubernetes_role_id

    add_index :kubernetes_deploy_group_roles, [:project_id, :deploy_group_id, :name], name: INDEX, length: {"name" => 191}
  end

  def remove_old_index
    remove_index :kubernetes_deploy_group_roles, name: INDEX
  end
end

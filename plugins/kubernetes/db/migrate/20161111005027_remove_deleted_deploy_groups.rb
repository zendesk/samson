# frozen_string_literal: true
class RemoveDeletedDeployGroups < ActiveRecord::Migration[5.0]
  class DeployGroupRole < ActiveRecord::Base
    self.table_name = 'kubernetes_deploy_group_roles'
  end

  class Role < ActiveRecord::Base
    self.table_name = 'kubernetes_roles'
  end

  def up
    existing_roles = Role.where.not(deleted_at: nil).pluck(:id)
    DeployGroupRole.where.not(kubernetes_role_id: existing_roles).delete_all
  end

  def down
  end
end

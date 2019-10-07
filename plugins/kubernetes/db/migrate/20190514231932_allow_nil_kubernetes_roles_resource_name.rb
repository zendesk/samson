# frozen_string_literal: true
class AllowNilKubernetesRolesResourceName < ActiveRecord::Migration[5.2]
  def change
    change_column_null :kubernetes_roles, :resource_name, true
  end
end

# frozen_string_literal: true
class AddSoftDeleteToKubernetesRole < ActiveRecord::Migration[4.2]
  def change
    add_column :kubernetes_roles, :deleted_at, :datetime
  end
end

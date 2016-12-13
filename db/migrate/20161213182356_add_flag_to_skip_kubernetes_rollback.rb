# frozen_string_literal: true
class AddFlagToSkipKubernetesRollback < ActiveRecord::Migration[5.0]
  def change
    add_column :deploys, :kubernetes_rollback, :boolean, default: true, null: false
  end
end

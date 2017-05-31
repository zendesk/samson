# frozen_string_literal: true
class LimitReplicasToo < ActiveRecord::Migration[5.1]
  def change
    add_column :kubernetes_usage_limits, :replicas, :integer, default: 2, null: false
    change_column_default :kubernetes_usage_limits, :replicas, nil
  end
end

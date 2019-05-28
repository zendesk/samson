# frozen_string_literal: true
class AddKritisBreakglass < ActiveRecord::Migration[5.2]
  def change
    add_column :kubernetes_clusters, :kritis_breakglass, :boolean, default: false, null: false
  end
end

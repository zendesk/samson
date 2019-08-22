# frozen_string_literal: true
class AddKubernetesHideLogsFlag < ActiveRecord::Migration[5.2]
  def change
    add_column :stages, :kubernetes_hide_error_logs, :boolean, default: false, null: false
  end
end

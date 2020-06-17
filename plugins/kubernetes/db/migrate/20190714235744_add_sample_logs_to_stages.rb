# frozen_string_literal: true
class AddSampleLogsToStages < ActiveRecord::Migration[5.2]
  def change
    add_column :stages, :kubernetes_sample_logs_on_success, :boolean, default: false, null: false
  end
end

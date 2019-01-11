# frozen_string_literal: true

class RemoveScanResultCacheCol < ActiveRecord::Migration[5.2]
  def change
    remove_column :builds, :gcr_vulnerabilities_status_id, :integer, default: 0, null: false
  end
end

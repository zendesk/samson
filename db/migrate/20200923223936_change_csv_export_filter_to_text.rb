# frozen_string_literal: true

class ChangeCsvExportFilterToText < ActiveRecord::Migration[6.0]
  def change
    change_column :csv_exports, :filters, :text, default: nil, null: true
  end
end

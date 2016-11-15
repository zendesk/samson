# frozen_string_literal: true
class ReleasesNumberToString < ActiveRecord::Migration[5.0]
  def change
    change_column :releases, :number, :string, limit: 20, default: "1", null: false
  end
end

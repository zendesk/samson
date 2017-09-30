# frozen_string_literal: true
class AddExternalBuildAttributes < ActiveRecord::Migration[5.1]
  def change
    add_column :builds, :external_id, :string
    add_index :builds, :external_id, unique: true, length: {external_id: 40}
    add_column :builds, :external_status, :string
    rename_column :builds, :source_url, :external_url
  end
end

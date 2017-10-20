# frozen_string_literal: true
class IncreaseBuildExternalIdIndexSize < ActiveRecord::Migration[5.1]
  def change
    remove_index :builds, :external_id
    add_index :builds, :external_id, unique: true, length: {external_id: 191}
  end
end

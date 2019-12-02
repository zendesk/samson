# frozen_string_literal: true
class AddDeletionTimeToStages < ActiveRecord::Migration[4.2]
  def change
    change_table :stages do |t|
      t.datetime :deleted_at
    end
  end
end

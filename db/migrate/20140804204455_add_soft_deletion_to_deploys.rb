# frozen_string_literal: true
class AddSoftDeletionToDeploys < ActiveRecord::Migration[4.2]
  def change
    add_column :deploys, :deleted_at, :timestamp
  end
end

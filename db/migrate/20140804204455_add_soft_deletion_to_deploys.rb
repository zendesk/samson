class AddSoftDeletionToDeploys < ActiveRecord::Migration
  def change
    add_column :deploys, :deleted_at, :timestamp
  end
end

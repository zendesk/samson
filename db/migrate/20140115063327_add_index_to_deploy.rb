class AddIndexToDeploy < ActiveRecord::Migration
  def change
    add_index :deploys, :created_at
  end
end

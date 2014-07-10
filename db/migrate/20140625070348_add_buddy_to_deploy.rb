class AddBuddyToDeploy < ActiveRecord::Migration
  def change
    add_column :deploys, :buddy_id, :integer
  end
end

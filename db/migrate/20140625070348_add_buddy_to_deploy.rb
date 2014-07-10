class AddBuddyToDeploy < ActiveRecord::Migration
  def change
    add_column :deploys, :buddy_id, :integer if ("1" == ENV["BUDDY_CHECK_FEATURE"])
  end
end

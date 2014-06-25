class AddBuddyToDeploy < ActiveRecord::Migration
  def change
    add_column :deploys, :buddy, :string
  end
end

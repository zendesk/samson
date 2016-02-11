class AddBypassBuddyCheckToStages < ActiveRecord::Migration
  def change
    add_column :stages, :bypass_buddy_check, :boolean, default: false
  end
end

class RenameBypassBuddyCheck < ActiveRecord::Migration
  def change
    rename_column :stages, :bypass_buddy_check, :no_code_deployed
  end
end

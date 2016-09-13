# frozen_string_literal: true
class RenameBypassBuddyCheck < ActiveRecord::Migration[4.2]
  def change
    rename_column :stages, :bypass_buddy_check, :no_code_deployed
  end
end

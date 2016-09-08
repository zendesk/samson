# frozen_string_literal: true
class AddBypassBuddyCheckToStages < ActiveRecord::Migration[4.2]
  def change
    add_column :stages, :bypass_buddy_check, :boolean, default: false
  end
end

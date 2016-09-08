# frozen_string_literal: true
class AddBuddyToDeploy < ActiveRecord::Migration[4.2]
  def change
    add_column :deploys, :buddy_id, :integer
  end
end

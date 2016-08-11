# frozen_string_literal: true
class RemoveUserFromMacro < ActiveRecord::Migration
  def change
    remove_column :macros, :user_id, :integer
  end
end

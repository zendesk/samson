# frozen_string_literal: true
class RemoveUserFromMacro < ActiveRecord::Migration[4.2]
  def change
    remove_column :macros, :user_id, :integer
  end
end

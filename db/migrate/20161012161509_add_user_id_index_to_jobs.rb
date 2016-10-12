# frozen_string_literal: true
class AddUserIdIndexToJobs < ActiveRecord::Migration[5.0]
  def change
    add_index :jobs, :user_id
  end
end

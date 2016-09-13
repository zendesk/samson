# frozen_string_literal: true
class JobsIndexOnStatus < ActiveRecord::Migration[4.2]
  def change
    add_index :jobs, :status, length: 191
  end
end

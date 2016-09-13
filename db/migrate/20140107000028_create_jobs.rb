# frozen_string_literal: true
class CreateJobs < ActiveRecord::Migration[4.2]
  def change
    create_table :jobs do |t|
      t.text :command, null: false
      t.integer :user_id, null: false
      t.integer :project_id, null: false
      t.string :status, default: "pending"
      t.text :output

      t.timestamps
    end
  end
end

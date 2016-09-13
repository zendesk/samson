# frozen_string_literal: true
class CreateDeploys < ActiveRecord::Migration[4.2]
  def change
    create_table :deploys do |t|
      t.integer :stage_id, null: false
      t.integer :job_id, null: false
      t.string :commit, null: false

      t.timestamps
    end
  end
end

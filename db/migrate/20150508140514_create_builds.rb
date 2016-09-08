# frozen_string_literal: true
class CreateBuilds < ActiveRecord::Migration[4.2]
  def change
    create_table :builds do |t|
      t.belongs_to :project,    null: false, index: true
      t.string :git_sha,        limit: 128
      t.string :git_ref
      t.string :container_sha, limit: 128, index: true
      t.string :container_ref
      t.timestamps

      t.index :git_sha, unique: true
    end
  end
end

# frozen_string_literal: true
class CreateLocks < ActiveRecord::Migration[4.2]
  def change
    create_table :locks do |t|
      t.belongs_to :stage
      t.belongs_to :user

      t.timestamps
      t.datetime :deleted_at
    end
  end
end

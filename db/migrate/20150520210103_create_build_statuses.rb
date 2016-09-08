# frozen_string_literal: true
class CreateBuildStatuses < ActiveRecord::Migration[4.2]
  def change
    create_table :build_statuses do |t|
      t.belongs_to :build, null: false, index: true
      t.string :source
      t.string :status, null: false, default: 'pending'
      t.string :url
      t.string :summary, limit: 512
      t.text :data
      t.timestamps
    end
  end
end

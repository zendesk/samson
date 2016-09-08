# frozen_string_literal: true
class RemoveBuildStatuses < ActiveRecord::Migration[4.2]
  def up
    drop_table :build_statuses
  end

  def down
    create_table "build_statuses" do |t|
      t.integer  "build_id", null: false
      t.string   "source",     limit: 255
      t.string   "status",     limit: 255, default: "pending", null: false
      t.string   "url",        limit: 255
      t.string   "summary",    limit: 512
      t.text     "data",       limit: 65535
      t.datetime "created_at"
      t.datetime "updated_at"
    end
    add_index "build_statuses", ["build_id"], name: "index_build_statuses_on_build_id", using: :btree
  end
end

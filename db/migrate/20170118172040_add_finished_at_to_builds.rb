# frozen_string_literal: true
class AddFinishedAtToBuilds < ActiveRecord::Migration[5.0]
  def change
    add_column :builds, :started_at, :datetime
    add_column :builds, :finished_at, :datetime
  end
end

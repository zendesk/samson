# frozen_string_literal: true
class AddStartedAtToDeploys < ActiveRecord::Migration[4.2]
  def change
    add_column :deploys, :started_at, :datetime
  end
end

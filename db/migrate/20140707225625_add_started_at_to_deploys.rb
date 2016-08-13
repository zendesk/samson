# frozen_string_literal: true
class AddStartedAtToDeploys < ActiveRecord::Migration
  def change
    add_column :deploys, :started_at, :timestamp
  end
end

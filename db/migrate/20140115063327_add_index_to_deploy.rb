# frozen_string_literal: true
class AddIndexToDeploy < ActiveRecord::Migration
  def change
    add_index :deploys, :created_at
  end
end

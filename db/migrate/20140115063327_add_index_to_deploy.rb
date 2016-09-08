# frozen_string_literal: true
class AddIndexToDeploy < ActiveRecord::Migration[4.2]
  def change
    add_index :deploys, :created_at
  end
end

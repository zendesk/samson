# frozen_string_literal: true
class AddIndices < ActiveRecord::Migration
  def change
    add_index :deploys, :stage_id
  end
end

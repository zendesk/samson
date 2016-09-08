# frozen_string_literal: true
class AddIndices < ActiveRecord::Migration[4.2]
  def change
    add_index :deploys, :stage_id
  end
end

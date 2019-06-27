# frozen_string_literal: true
class RemoveUniqueIndexFromWebhooks < ActiveRecord::Migration[4.2]
  def change
    remove_index :webhooks, :stage_id_and_branch
    add_index :webhooks, [:stage_id, :branch], length: {branch: 191}
  end
end

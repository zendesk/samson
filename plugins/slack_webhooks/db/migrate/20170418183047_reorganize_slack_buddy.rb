# frozen_string_literal: true
class ReorganizeSlackBuddy < ActiveRecord::Migration[5.0]
  def change
    rename_column :slack_webhooks, :for_buddy, :buddy_box
    add_column :slack_webhooks, :buddy_request, :boolean, default: false, null: false
  end
end

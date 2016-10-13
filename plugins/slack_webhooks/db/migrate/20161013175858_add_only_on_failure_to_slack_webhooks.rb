# frozen_string_literal: true
class AddOnlyOnFailureToSlackWebhooks < ActiveRecord::Migration[5.0]
  def change
    add_column :slack_webhooks, :only_on_failure, :boolean, default: false, null: false
  end
end

# frozen_string_literal: true
class AddDisabledToWebhooks < ActiveRecord::Migration[5.2]
  def change
    add_column :webhooks, :disabled, :boolean, default: false, null: false
  end
end

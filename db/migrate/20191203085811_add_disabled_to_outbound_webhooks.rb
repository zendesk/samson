# frozen_string_literal: true
class AddDisabledToOutboundWebhooks < ActiveRecord::Migration[5.2]
  def change
    add_column :outbound_webhooks, :disabled, :boolean, default: false, null: false
  end
end

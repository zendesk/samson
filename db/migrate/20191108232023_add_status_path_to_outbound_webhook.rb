# frozen_string_literal: true
class AddStatusPathToOutboundWebhook < ActiveRecord::Migration[5.2]
  def change
    add_column :outbound_webhooks, :status_path, :string
  end
end

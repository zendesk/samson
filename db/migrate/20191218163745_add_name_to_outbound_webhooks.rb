# frozen_string_literal: true
class AddNameToOutboundWebhooks < ActiveRecord::Migration[6.0]
  class OutboundWebhook < ActiveRecord::Base
  end

  def change
    add_column :outbound_webhooks, :name, :string
    add_index :outbound_webhooks, :name, unique: true, length: 191
    OutboundWebhook.reset_column_information
    OutboundWebhook.where(global: true).each do |w|
      w.update_column :name, w.url
    end
  end
end

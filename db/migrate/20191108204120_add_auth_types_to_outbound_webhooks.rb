# frozen_string_literal: true
class AddAuthTypesToOutboundWebhooks < ActiveRecord::Migration[5.2]
  class OutboundWebhook < ActiveRecord::Base
  end

  def change
    add_column :outbound_webhooks, :auth_type, :string, default: "Basic", null: false
    change_column_default :outbound_webhooks, :auth_type, from: "Basic", to: nil
    OutboundWebhook.where("username is NULL OR username = ''").update_all(auth_type: "None")

    add_column :outbound_webhooks, :insecure, :boolean, default: false, null: false
  end
end

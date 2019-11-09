# frozen_string_literal: true
class RemoveDeletedWebhookColumns < ActiveRecord::Migration[5.2]
  class OutboundWebhook < ActiveRecord::Base
  end

  def change
    OutboundWebhook.where("deleted_at IS NOT NULL").delete_all

    remove_column :outbound_webhooks, :stage_id
    remove_column :outbound_webhooks, :project_id
    remove_column :outbound_webhooks, :deleted_at
  end
end

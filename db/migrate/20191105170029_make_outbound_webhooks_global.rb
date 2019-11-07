# frozen_string_literal: true
class MakeOutboundWebhooksGlobal < ActiveRecord::Migration[5.2]
  class OutboundWebhook < ActiveRecord::Base
  end

  class OutboundWebhookStage < ActiveRecord::Base
  end

  def change
    create_table :outbound_webhook_stages do |t|
      t.integer :stage_id, null: false
      t.integer :outbound_webhook_id, null: false
      t.timestamps
      t.index :stage_id
      t.index [:outbound_webhook_id, :stage_id], unique: true, name: "index_on_outbound_webhook_id"
    end

    add_column :outbound_webhooks, :global, :boolean, default: false, null: false

    OutboundWebhook.find_each do |wh|
      OutboundWebhookStage.create!(stage_id: wh.stage_id, outbound_webhook_id: wh.id) do |o|
        o.created_at = wh.created_at
        o.updated_at = o.updated_at
      end
    end

    # make previously running code not blow up from missing columns
    # later we will deploy a migration to delete these columns
    change_column_default :outbound_webhooks, :stage_id, from: nil, to: 0
    change_column_default :outbound_webhooks, :project_id, from: nil, to: 0

    # TODO: cleanup project_id / stage_id on outbound_webhooks
  end
end

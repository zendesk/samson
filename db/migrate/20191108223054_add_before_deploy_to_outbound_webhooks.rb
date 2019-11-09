# frozen_string_literal: true
class AddBeforeDeployToOutboundWebhooks < ActiveRecord::Migration[5.2]
  def change
    add_column :outbound_webhooks, :before_deploy, :boolean, default: false, null: false
  end
end

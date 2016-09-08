# frozen_string_literal: true
class AddCheckboxesToSlackWebhooks < ActiveRecord::Migration[4.2]
  def change
    add_column :slack_webhooks, :before_deploy, :boolean, default: false, null: false
    add_column :slack_webhooks, :after_deploy, :boolean, default: true, null: false
    add_column :slack_webhooks, :for_buddy, :boolean, default: false, null: false
  end
end

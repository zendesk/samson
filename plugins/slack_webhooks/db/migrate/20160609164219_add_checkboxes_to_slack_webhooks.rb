class AddCheckboxesToSlackWebhooks < ActiveRecord::Migration
  def change
    add_column :slack_webhooks, :before_deploy, :boolean, default: false
    add_column :slack_webhooks, :after_deploy, :boolean, default: true
    add_column :slack_webhooks, :for_buddy, :boolean, default: false
  end
end

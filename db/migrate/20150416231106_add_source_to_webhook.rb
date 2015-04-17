class AddSourceToWebhook < ActiveRecord::Migration
  def change
    add_column :webhooks, :source, :string, default: 'any_ci'
    Webhook.update_all source: 'any_ci'
  end
end

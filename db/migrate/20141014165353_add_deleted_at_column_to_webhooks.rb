# frozen_string_literal: true
class AddDeletedAtColumnToWebhooks < ActiveRecord::Migration
  def change
    add_column :webhooks, :deleted_at, :timestamp
  end
end

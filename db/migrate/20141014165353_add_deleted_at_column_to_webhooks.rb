# frozen_string_literal: true
class AddDeletedAtColumnToWebhooks < ActiveRecord::Migration[4.2]
  def change
    add_column :webhooks, :deleted_at, :datetime
  end
end

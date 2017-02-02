# frozen_string_literal: true
class AddCancelQueuedDeploysToStages < ActiveRecord::Migration[5.0]
  def change
    add_column :stages, :cancel_queued_deploys, :boolean, default: false, null: false
  end
end

# frozen_string_literal: true

class AddRedeployPreviousWhenFailed < ActiveRecord::Migration[5.2]
  def change
    add_column :stages, :allow_redeploy_previous_when_failed, :boolean, default: false, null: false
    add_column :deploys, :redeploy_previous_when_failed, :boolean, default: false, null: false
  end
end

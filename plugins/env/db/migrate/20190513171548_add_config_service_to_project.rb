# frozen_string_literal: true
class AddConfigServiceToProject < ActiveRecord::Migration[5.2]
  def change
    add_column :projects, :config_service, :boolean, default: false, null: false
  end
end

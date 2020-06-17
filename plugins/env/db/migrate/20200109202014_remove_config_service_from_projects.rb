# frozen_string_literal: true
class RemoveConfigServiceFromProjects < ActiveRecord::Migration[6.0]
  def change
    remove_column :projects, :config_service
  end
end

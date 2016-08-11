# frozen_string_literal: true
class RemoveDeployStrategy < ActiveRecord::Migration
  def change
    remove_column :kubernetes_roles, :deploy_strategy, :string, null: false
  end
end

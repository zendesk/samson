# frozen_string_literal: true
class RemoveKubernetesJob < ActiveRecord::Migration[5.1]
  def change
    remove_column :builds, :kubernetes_job, :boolean, default: false, null: false
  end
end

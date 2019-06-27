# frozen_string_literal: true
class AddRolloutTimeoutToProjects < ActiveRecord::Migration[5.2]
  def change
    add_column :projects, :kubernetes_rollout_timeout, :integer
  end
end

# frozen_string_literal: true
class AddDeployToKubernetesRelease < ActiveRecord::Migration
  def change
    add_column :kubernetes_releases, :deploy_id, :integer
  end
end

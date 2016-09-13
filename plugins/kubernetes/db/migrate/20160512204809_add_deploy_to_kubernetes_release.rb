# frozen_string_literal: true
class AddDeployToKubernetesRelease < ActiveRecord::Migration[4.2]
  def change
    add_column :kubernetes_releases, :deploy_id, :integer
  end
end

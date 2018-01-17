# frozen_string_literal: true
class AddBluePhaseToKubernetesReleases < ActiveRecord::Migration[5.1]
  def change
    add_column :kubernetes_releases, :blue_phase, :boolean, default: false, null: false
  end
end

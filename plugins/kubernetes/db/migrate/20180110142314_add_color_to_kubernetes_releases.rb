class AddColorToKubernetesReleases < ActiveRecord::Migration[5.1]
  def change
    add_column :kubernetes_releases, :color, :string, limit: 8, null: true
  end
end

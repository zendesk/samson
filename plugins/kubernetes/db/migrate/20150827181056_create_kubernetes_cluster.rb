# frozen_string_literal: true
class CreateKubernetesCluster < ActiveRecord::Migration[4.2]
  def change
    create_table :kubernetes_clusters do |t|
      t.string :name
      t.string :description
      t.string :config_filepath
      t.string :config_context
      t.timestamps
    end
  end
end

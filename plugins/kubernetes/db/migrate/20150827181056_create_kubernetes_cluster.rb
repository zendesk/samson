class CreateKubernetesCluster < ActiveRecord::Migration
  def change
    create_table :kubernetes_clusters do |t|
      t.string :name
      t.string :description
      t.string :api_version
      t.string :url, null: false
      t.boolean :use_ssl
      t.string :username
      t.timestamps
    end
  end
end

class CreateKubernetesTasks < ActiveRecord::Migration
  def change
    create_table :kubernetes_tasks do |t|
      t.references :project, null: false, index: true
      t.string :name, null: false
      t.string :config_file
      t.timestamp :deleted_at
      t.timestamps null: false
    end
  end
end

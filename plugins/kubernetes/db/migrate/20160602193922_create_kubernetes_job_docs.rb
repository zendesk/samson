class CreateKubernetesJobDocs < ActiveRecord::Migration
  def change
    create_table :kubernetes_job_docs do |t|
      t.references :job, null: false, index: true
      t.references :deploy_group, null: false, index: true
      t.string :status, null: false, default: "created"
      t.timestamps null: false
    end
  end
end

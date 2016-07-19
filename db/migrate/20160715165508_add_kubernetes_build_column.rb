class AddKubernetesBuildColumn < ActiveRecord::Migration
  def change
    add_column :builds, :kubernetes_job, :boolean, default: false, null: false
  end
end

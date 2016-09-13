# frozen_string_literal: true
class AddKubernetesBuildColumn < ActiveRecord::Migration[4.2]
  def change
    add_column :builds, :kubernetes_job, :boolean, default: false, null: false
  end
end

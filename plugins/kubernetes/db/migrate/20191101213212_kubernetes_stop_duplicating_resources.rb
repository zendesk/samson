# frozen_string_literal: true
# TODO: run this after the new code is live ...
class KubernetesStopDuplicatingResources < ActiveRecord::Migration[5.2]
  def change
    remove_column :kubernetes_release_docs, :limits_cpu
    remove_column  :kubernetes_release_docs, :limits_memory
    remove_column  :kubernetes_release_docs, :requests_cpu
    remove_column :kubernetes_release_docs, :requests_memory
    remove_column :kubernetes_release_docs, :no_cpu_limit
  end
end

# frozen_string_literal: true
class KubernetesStopDuplicatingResources < ActiveRecord::Migration[5.2]
  def change
    remove_column :kubernetes_release_docs, :limits_cpu rescue false # rubocop:disable Style/RescueModifier was deleted before by accident
    remove_column  :kubernetes_release_docs, :limits_memory
    remove_column  :kubernetes_release_docs, :requests_cpu
    remove_column :kubernetes_release_docs, :requests_memory
    remove_column :kubernetes_release_docs, :no_cpu_limit
  end
end

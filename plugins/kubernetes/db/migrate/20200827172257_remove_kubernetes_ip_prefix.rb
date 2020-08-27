# frozen_string_literal: true
class RemoveKubernetesIpPrefix < ActiveRecord::Migration[6.0]
  def change
    remove_column :kubernetes_clusters, :ip_prefix, :string
  end
end

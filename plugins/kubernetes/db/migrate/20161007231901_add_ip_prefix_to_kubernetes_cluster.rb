# frozen_string_literal: true
class AddIpPrefixToKubernetesCluster < ActiveRecord::Migration[5.0]
  def change
    add_column :kubernetes_clusters, :ip_prefix, :string
  end
end

# frozen_string_literal: true
class AddClusterConfig < ActiveRecord::Migration[5.2]
  def change
    add_column :kubernetes_clusters, :auth_method, :string, null: false, default: "context"
    add_column :kubernetes_clusters, :api_endpoint, :string
    add_column :kubernetes_clusters, :encrypted_client_cert, :text
    add_column :kubernetes_clusters, :encrypted_client_cert_iv, :string
    add_column :kubernetes_clusters, :encrypted_client_key, :text
    add_column :kubernetes_clusters, :encrypted_client_key_iv, :string
    add_column :kubernetes_clusters, :encryption_key_sha, :string
    add_column :kubernetes_clusters, :verify_ssl, :boolean, null: false, default: false
  end
end

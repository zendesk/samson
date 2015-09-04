require 'kubeclient'

module Kubernetes
  class Cluster < ActiveRecord::Base
    self.table_name = 'kubernetes_clusters'
    has_many :deploy_groups, inverse_of: 'kubernetes_cluster', foreign_key: 'kubernetes_cluster_id'

    validates :name, presence: true, uniqueness: true
    validates :url, presence: true
    validates :api_version, presence: true
    validate :test_client_connection

    def client
      @client ||= Kubeclient::Client.new(url, api_version)
    end

    def connection_valid?
      client.api_valid?
    rescue Errno::ECONNREFUSED
      false
    end

    def namespace_exists?(namespace)
      client.get_namespace(namespace).present?
    rescue KubeException
      false
    end

    private

    def test_client_connection
      errors.add(:url, "Could not connect to API Server") unless connection_valid?
    end
  end
end

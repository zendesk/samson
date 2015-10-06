require 'kubeclient'

module Kubernetes
  class Cluster < ActiveRecord::Base
    self.table_name = 'kubernetes_clusters'
    has_many :deploy_groups, inverse_of: 'kubernetes_cluster', foreign_key: 'kubernetes_cluster_id'

    validates :name, presence: true, uniqueness: true
    validates :config_filepath, presence: true
    validates :config_context, presence: true
    validate :test_client_connection

    def client
      @client ||= config_file.client_for(config_context)
    end

    def config_file
      @config_file ||= Kubernetes::ClientConfigFile.new(config_filepath)
    end

    def connection_valid?
      client.api_valid?
    rescue Errno::ECONNREFUSED
      false
    end

    def namespace_exists?(namespace)
      connection_valid? && client.get_namespace(namespace).present?
    rescue KubeException
      false
    end

    private

    def test_client_connection
      if File.exists?(config_filepath)
        errors.add(:config_context, "Could not connect to API Server") unless connection_valid?
      else
        errors.add(:config_filepath, "File does not exist")
      end
    end
  end
end

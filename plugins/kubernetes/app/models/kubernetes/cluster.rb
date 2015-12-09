require 'kubeclient'

module Kubernetes
  class Cluster < ActiveRecord::Base
    self.table_name = 'kubernetes_clusters'
    has_many :cluster_deploy_groups, class_name: 'Kubernetes::ClusterDeployGroup', foreign_key: :kubernetes_cluster_id
    has_many :deploy_groups, through: :cluster_deploy_groups

    validates :name, presence: true, uniqueness: true
    validates :config_filepath, presence: true
    validates :config_context, presence: true
    validate :test_client_connection

    def client
      @client ||= kubeconfig.client_for(config_context)
    end

    def ext_client
      @ext_client ||= kubeconfig.ext_client_for(config_context)
    end

    def context
      @context ||= kubeconfig.contexts[config_context]
    end

    def username
      context.user.try(:username)
    end

    def namespaces
      client.get_namespaces.map { |ns| ns.metadata.name } - %w[kube-system]
    end

    def connection_valid?
      client.api_valid?
    rescue Errno::ECONNREFUSED
      false
    end

    def namespace_exists?(namespace)
      connection_valid? && namespaces.include?(namespace)
    rescue KubeException
      false
    end

    private

    def kubeconfig
      @config_file ||= Kubernetes::ClientConfigFile.new(config_filepath)
    end

    def test_client_connection
      if File.exists?(config_filepath)
        errors.add(:config_context, "Could not connect to API Server") unless connection_valid?
      else
        errors.add(:config_filepath, "File does not exist")
      end
    end
  end
end

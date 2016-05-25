require 'kubeclient'
require 'celluloid/io'

module Kubernetes
  class Cluster < ActiveRecord::Base
    self.table_name = 'kubernetes_clusters'
    has_many :cluster_deploy_groups, class_name: 'Kubernetes::ClusterDeployGroup', foreign_key: :kubernetes_cluster_id
    has_many :deploy_groups, through: :cluster_deploy_groups

    validates :name, presence: true, uniqueness: true
    validates :config_filepath, presence: true
    validates :config_context, presence: true
    validate :test_client_connection

    def watch!
      Watchers::ClusterPodWatcher.restart_watcher(self)
      Watchers::ClusterPodErrorWatcher.restart_watcher(self)
    end

    def client
      @client ||= Kubeclient::Client.new(
        context.api_endpoint,
        context.api_version,
        ssl_options: context.ssl_options,
        socket_options: client_socket_options
      )
    end

    def extension_client
      @extension_client ||= Kubeclient::Client.new(
        context.api_endpoint.gsub(/\/api$/, '') + '/apis',
        'extensions/v1beta1',
        ssl_options: context.ssl_options,
        socket_options: client_socket_options
      )
    end

    def context
      @context ||= kubeconfig.context(config_context)
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

    def kubeconfig
      @kubeconfig ||= Kubeclient::Config.read(config_filepath)
    end

    private

    def test_client_connection
      if File.exist?(config_filepath)
        errors.add(:config_context, "Could not connect to API Server") unless connection_valid?
      else
        errors.add(:config_filepath, "File does not exist")
      end
    end

    def client_socket_options
      if context.ssl_options[:verify_ssl] == OpenSSL::SSL::VERIFY_PEER
        { ssl_socket_class: Celluloid::IO::SSLSocket }
      else
        { socket_class: Celluloid::IO::TCPSocket }
      end
    end
  end
end

# frozen_string_literal: true
require 'kubeclient'

module Kubernetes
  class Cluster < ActiveRecord::Base
    self.table_name = 'kubernetes_clusters'

    IP_PREFIX_PATTERN = /\A(?:[\d]{1,3}\.){0,2}[\d]{1,3}\z/ # also used in js

    has_many :cluster_deploy_groups, class_name: 'Kubernetes::ClusterDeployGroup', foreign_key: :kubernetes_cluster_id
    has_many :deploy_groups, through: :cluster_deploy_groups

    validates :name, presence: true, uniqueness: true
    validates :config_filepath, presence: true
    validates :config_context, presence: true
    validates :ip_prefix, format: IP_PREFIX_PATTERN, allow_blank: true
    validate :test_client_connection

    def client
      @client ||= build_client :default
    end

    def extension_client
      @extension_client ||= build_client 'extensions/v1beta1'
    end

    def context
      @context ||= kubeconfig.context(config_context)
    end

    def namespaces
      client.get_namespaces.map { |ns| ns.metadata.name } - %w[kube-system]
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

    def connection_valid?
      client.api_valid?
    rescue KubeException, Errno::ECONNREFUSED
      false
    end

    def build_client(type)
      endpoint = context.api_endpoint
      if type == :default
        type = context.api_version
      else
        endpoint = endpoint.sub(/\/api$/, '') + '/apis'
      end

      Kubeclient::Client.new(
        endpoint,
        type,
        ssl_options: context.ssl_options,
        auth_options: context.auth_options
      )
    end

    def test_client_connection
      if File.file?(config_filepath)
        unless connection_valid?
          errors.add(:config_context, "Could not connect to API Server")
        end
      else
        errors.add(:config_filepath, "File does not exist")
      end
    end
  end
end

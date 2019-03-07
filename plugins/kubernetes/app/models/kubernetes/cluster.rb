# frozen_string_literal: true
require 'kubeclient'

module Kubernetes
  class Cluster < ActiveRecord::Base
    self.table_name = 'kubernetes_clusters'
    audited

    IP_PREFIX_PATTERN = /\A(?:[\d]{1,3}\.){0,2}[\d]{1,3}\z/ # also used in js

    has_many :cluster_deploy_groups,
      class_name: 'Kubernetes::ClusterDeployGroup',
      foreign_key: :kubernetes_cluster_id,
      dependent: nil
    has_many :deploy_groups, through: :cluster_deploy_groups

    validates :name, presence: true, uniqueness: true
    validates :config_filepath, presence: true
    validates :config_context, presence: true
    validates :ip_prefix, format: IP_PREFIX_PATTERN, allow_blank: true
    validate :test_client_connection

    before_destroy :ensure_unused

    def client(type)
      (@client ||= {})[type] ||= build_client(type)
    end

    def namespaces
      client('v1').get_namespaces.fetch(:items).map { |ns| ns.dig(:metadata, :name) } - %w[kube-system]
    end

    def kubeconfig
      @kubeconfig ||= Kubeclient::Config.read(config_filepath)
    end

    def schedulable_nodes
      nodes = client('v1').get_nodes.fetch(:items)
      nodes.reject { |n| n.dig(:spec, :unschedulable) }
    rescue *SamsonKubernetes.connection_errors
      Rails.logger.error("Error loading nodes from cluster #{id}: #{$!}")
      []
    end

    def server_version
      version = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
        JSON.parse(client('v1').create_rest_client('version').get.body).fetch('gitVersion')[1..-1]
      end
      Gem::Version.new(version)
    end

    private

    def connection_valid?
      client('v1').api_valid?
    rescue *SamsonKubernetes.connection_errors
      false
    end

    def build_client(type)
      context = kubeconfig.context(config_context)
      endpoint = context.api_endpoint
      endpoint += '/apis' unless type.match? /^v\d+/ # TODO: remove by fixing via https://github.com/abonas/kubeclient/issues/284

      Kubeclient::Client.new(
        endpoint,
        type,
        ssl_options: context.ssl_options,
        auth_options: context.auth_options,
        timeouts: {open: 2, read: 10},
        as: :parsed_symbolized
      )
    end

    def test_client_connection
      unless File.file?(config_filepath)
        errors.add(:config_filepath, "File does not exist")
        return
      end

      unless kubeconfig.contexts.include?(config_context)
        errors.add(:config_context, "Context not found")
        return
      end

      unless connection_valid?
        errors.add(:config_context, "Could not connect to API Server")
        return
      end
    end

    def ensure_unused
      if groups = deploy_groups.presence
        errors.add(:base, "Cannot be deleted since it is currently used by #{groups.map(&:name).join(", ")}.")
        throw(:abort)
      end
    end
  end
end

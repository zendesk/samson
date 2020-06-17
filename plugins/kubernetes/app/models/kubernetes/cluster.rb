# frozen_string_literal: true
require 'kubeclient'

module Kubernetes
  class Cluster < ActiveRecord::Base
    self.table_name = 'kubernetes_clusters'
    audited

    include AttrEncryptedSupport
    attr_encrypted :client_cert
    attr_encrypted :client_key

    IP_PREFIX_PATTERN = /\A(?:[\d]{1,3}\.){0,2}[\d]{1,3}\z/.freeze # also used in js

    has_many :cluster_deploy_groups,
      class_name: 'Kubernetes::ClusterDeployGroup',
      foreign_key: :kubernetes_cluster_id,
      dependent: nil,
      inverse_of: :cluster
    has_many :deploy_groups, through: :cluster_deploy_groups, inverse_of: :kubernetes_cluster

    validates :name, presence: true, uniqueness: {case_sensitive: false}
    validates :ip_prefix, format: IP_PREFIX_PATTERN, allow_blank: true
    validate :test_client_connection

    before_destroy :ensure_unused

    def client(type)
      (@client ||= {})[[Thread.current.object_id, type]] ||= begin
        case auth_method
        when "context"
          context = kubeconfig.context(config_context)
          endpoint = context.api_endpoint
          ssl_options = context.ssl_options
          auth_options = context.auth_options
        when "database"
          endpoint = api_endpoint
          ssl_options = {
            client_cert: client_cert_object,
            client_key: client_key_object,
            verify_ssl: verify_ssl
          }
          auth_options = {}
        else raise "Unsupported auth method #{auth_method}"
        end

        endpoint += '/apis' unless type.match? /^v\d+/ # TODO: remove by fixing via https://github.com/abonas/kubeclient/issues/284

        Kubeclient::Client.new(
          endpoint,
          type,
          ssl_options: ssl_options,
          auth_options: auth_options,
          timeouts: {open: 3, read: 10},
          as: :parsed_symbolized
        )
      end
    end

    def namespaces
      client('v1').get_namespaces.fetch(:items).map { |ns| ns.dig(:metadata, :name) } - ["kube-system"]
    end

    def config_contexts
      (config_filepath? ? kubeconfig.contexts : [])
    rescue StandardError
      []
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
        Samson::Retry.with_retries [StandardError], 3, wait_time: 1 do
          JSON.parse(client('v1').create_rest_client('version').get.body).fetch('gitVersion')[1..-1]
        end
      end
      Gem::Version.new(version)
    end

    private

    def client_key_object
      (OpenSSL::PKey::RSA.new(client_key) if client_key?)
    end

    def client_cert_object
      (OpenSSL::X509::Certificate.new(client_cert) if client_cert?)
    end

    def kubeconfig
      @kubeconfig ||= Kubeclient::Config.read(config_filepath)
    end

    def connection_valid?
      client('v1').api_valid?
    rescue StandardError
      false
    end

    def test_client_connection
      case auth_method
      when "context"
        return errors.add(:config_filepath, "must be set") unless config_filepath?
        return errors.add(:config_filepath, "file does not exist") unless File.file?(config_filepath)
        return errors.add(:config_context, "must be set") unless config_context?
        return errors.add(:config_context, "not found") unless config_contexts.include?(config_context)
      when "database"
        return errors.add(:api_endpoint, "must be set") unless api_endpoint?
        begin
          client_cert_object
        rescue StandardError
          errors.add(:client_cert, "is invalid")
        end

        begin
          client_key_object
        rescue StandardError
          errors.add(:client_key, "is invalid")
        end
      else
        errors.add(:auth_method, "pick 'context' or 'database'")
      end

      errors.add(:base, "Could not connect to API Server") unless connection_valid?
    end

    def ensure_unused
      if groups = deploy_groups.presence
        errors.add(:base, "Cannot be deleted since it is currently used by #{groups.map(&:name).join(", ")}.")
        throw(:abort)
      end
    end
  end
end

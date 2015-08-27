require 'kubeclient'

module Kubernetes
  class Cluster < ActiveRecord::Base
    self.table_name = 'kubernetes_clusters'
    has_many :deploy_groups, inverse_of: 'kubernetes_cluster', foreign_key: 'kubernetes_cluster_id'

    validates :name, presence: true, uniqueness: true
    validates :url, presence: true
    validates :api_version, presence: true
    validate :test_client_connection

    delegate :config_file, to: 'self.class'

    def client
      @client ||= begin
        options = {}
        options[:ssl_options] = ssl_options if use_ssl?
        Kubeclient::Client.new(url, api_version, options)
      end
    end

    def connection_valid?
      client.api_valid?
    rescue Errno::ECONNREFUSED
      false
    end

    def deploy_group_ids
      deploy_groups.map(&:id)
    end

    def deploy_group_ids=(new_ids)
      new_ids = new_ids.map(&:to_i).uniq.select { |v| v > 0 }

      deploy_groups.each do |dg|
        deploy_groups.delete(dg) unless new_ids.include?(dg.id)
      end

      groups_to_add = new_ids - deploy_group_ids

      if groups_to_add.any?
        DeployGroup.where(id: groups_to_add).each do |dg|
          deploy_groups << dg
        end
      end

      deploy_group_ids
    end

    def self.config_file
      @config_file ||= begin
        config_file = ENV['KUBE_CONFIG_FILE'].presence || "#{ENV.fetch('HOME')}/.kube/config"
        YAML.load_file(config_file).with_indifferent_access if File.exists?(config_file)
      end
    end

    private

    def set_defaults_from_config
      if config_file
        self.api_version = config_file[:apiVersion]
        self.url = cluster_hash[:cluster][:server] + '/api/'
      end
    end

    def cluster_hash
      if config_file && name.present?
        config_file[:clusters].detect { |h| h[:name] == name }
      end
    end

    def user_hash
      if config_file && username.present?
        config_file[:users].detect { |h| h[:name] == username }
      end
    end

    def ssl_options
      @ssl_options ||= begin
        {
          client_cert: OpenSSL::X509::Certificate.new(client_cert),
          client_key:  OpenSSL::PKey::RSA.new(client_key),
          ca_file:     ca_filepath,
          verify_ssl:  OpenSSL::SSL::VERIFY_PEER
        }
      end
    end

    def client_cert
      @client_cert ||= Base64.decode64(user_hash[:user][:'client-certificate-data'])
    end

    def client_key
      @client_key ||= Base64.decode64(user_hash[:user][:'client-key-data'])
    end

    def ca_filepath
      @ca_filepath ||= begin
        filepath = "#{ENV.fetch('HOME')}/.kube/ca.crt"
        File.write(filepath, Base64.decode64(cluster_hash[:cluster][:'certificate-authority-data']))
        filepath
      end
    end

    def test_client_connection
      errors.add(:url, "Could not connect to API Server") unless connection_valid?
    end
  end
end

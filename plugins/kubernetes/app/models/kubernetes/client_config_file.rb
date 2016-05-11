require 'celluloid/io'

module Kubernetes
  # Parses the kubeconfig file that contains cluster information
  # http://kubernetes.io/docs/user-guide/kubeconfig-file/
  class ClientConfigFile
    attr_reader :filepath, :api_version, :clusters, :users, :contexts

    def initialize(filepath)
      @filepath = File.expand_path(filepath)
      raise ArgumentError.new("File #{@filepath} does not exist") unless File.exists?(@filepath)
      @config_file = YAML.load_file(@filepath).with_indifferent_access
      parse_file
    end

    def current_client
      client_for(@current_context)
    end

    def client_for(context_name)
      contexts[context_name].try(:client)
    end

    def extension_client_for(context_name)
      contexts[context_name].try(:extension_client)
    end

    def context_names
      contexts.keys
    end

    private

    def parse_file
      @api_version = @config_file.fetch(:apiVersion)
      @current_context = @config_file.fetch(:'current-context')
      parse_clusters
      parse_users
      parse_contexts
    end

    def parse_clusters
      @clusters = {}
      (@config_file[:clusters] || []).each do |cluster_hash|
        cluster = Cluster.new
        cluster.name = cluster_hash[:name]
        cluster.server = cluster_hash[:cluster][:server]
        ca_data = fetch_cluster_ca_data(cluster_hash[:cluster])
        if ca_data
          cluster.cert_store = OpenSSL::X509::Store.new
          cluster.cert_store.add_cert(OpenSSL::X509::Certificate.new(ca_data))
        else
          cluster.cert_store = nil
        end
        @clusters[cluster.name] = cluster
      end
    end

    def parse_users
      @users = {}
      (@config_file[:users] || []).each do |user_hash|
        user = User.new
        user.name = user_hash[:name]
        user.username = user_hash[:user][:username]
        user.password = user_hash[:user][:password]

        client_cert_data = fetch_user_cert_data(user_hash[:user])
        if client_cert_data
          user.client_cert = OpenSSL::X509::Certificate.new(client_cert_data)
        end

        client_key_data  = fetch_user_key_data(user_hash[:user])
        if client_key_data
          user.client_key = OpenSSL::PKey::RSA.new(client_key_data)
        end

        @users[user.name] = user
      end
    end

    def parse_contexts
      @contexts = {}
      (@config_file[:contexts] || []).each do |context_hash|
        context = Context.new
        context.name = context_hash[:name]
        context.api_version = api_version
        context.cluster = @clusters.fetch(context_hash[:context][:cluster])
        context.user = @users.fetch(context_hash[:context][:user]) if context_hash[:context][:user].present?
        @contexts[context.name] = context
      end
    end

    def ext_file_path(path)
      File.join(File.dirname(@filepath), path)
    end

    def fetch_cluster_ca_data(cluster)
      if cluster.key?('certificate-authority')
        File.read(ext_file_path(cluster['certificate-authority']))
      elsif cluster.key?('certificate-authority-data')
        Base64.decode64(cluster['certificate-authority-data'])
      end
    end

    def fetch_user_cert_data(user)
      if user.key?('client-certificate')
        File.read(ext_file_path(user['client-certificate']))
      elsif user.key?('client-certificate-data')
        Base64.decode64(user['client-certificate-data'])
      end
    end

    def fetch_user_key_data(user)
      if user.key?('client-key')
        File.read(ext_file_path(user['client-key']))
      elsif user.key?('client-key-data')
        Base64.decode64(user['client-key-data'])
      end
    end

    public

    class User
      attr_accessor :name, :username, :password, :client_cert, :client_key
    end

    class Cluster
      attr_accessor :name, :server, :cert_store

      def url
        server + '/api/'
      end
    end

    class Context
      attr_accessor :name, :cluster, :user, :api_version

      def client
        build_client(cluster.url, api_version)
      end

      def extension_client
        build_client(cluster.server + '/apis', 'extensions/v1beta1')
      end

      def build_client(url, version)
        Kubeclient::Client.new(url, version, ssl_options: ssl_options, socket_options: socket_options)
      end

      def use_ssl?
        cluster.cert_store.present? && user.client_cert.present?
      end

      def ssl_options
        return {} unless use_ssl?

        {
          client_cert: user.client_cert,
          client_key:  user.client_key,
          cert_store:  cluster.cert_store,
          verify_ssl:  OpenSSL::SSL::VERIFY_PEER
        }
      end

      def socket_options
        if use_ssl?
          { ssl_socket_class: Celluloid::IO::SSLSocket }
        else
          { socket_class: Celluloid::IO::TCPSocket }
        end
      end
    end
  end
end

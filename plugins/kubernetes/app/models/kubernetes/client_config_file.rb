module Kubernetes
  class ClientConfigFile
    attr_reader :filepath, :api_version, :clusters, :users, :contexts

    def initialize(filepath)
      raise ArgumentError.new("File #{filepath} does not exist") unless File.exists?(filepath)
      @filepath = filepath
      @config_file = YAML.load_file(filepath).with_indifferent_access
      parse_file
    end

    def exists?
      config_file.present?
    end

    def current_client
      client_for(@current_context)
    end

    def client_for(context_name)
      contexts[context_name].try(:client)
    end

    def ext_client_for(context_name)
      contexts[context_name].try(:ext_client)
    end

    def context_names
      contexts.keys
    end

    private

    def parse_file
      @api_version = @config_file[:apiVersion]
      @current_context = @config_file[:'current-context']
      parse_clusters
      parse_users
      parse_contexts
    end

    def parse_clusters
      @clusters = {}
      @config_file[:clusters].each do |cluster_hash|
        cluster = Cluster.new
        cluster.name = cluster_hash[:name]
        cluster.server = cluster_hash[:cluster][:server]
        cluster.ca_data = cluster_hash[:cluster][:'certificate-authority-data']
        @clusters[cluster.name] = cluster
      end
    end

    def parse_users
      @users = {}
      @config_file[:users].each do |user_hash|
        user = User.new
        user.name = user_hash[:name]
        user.username = user_hash[:user][:username]
        user.password = user_hash[:user][:password]
        if user_hash[:user][:'client-certificate-data']
          cert_data = Base64.decode64(user_hash[:user][:'client-certificate-data'])
          user.client_cert = OpenSSL::X509::Certificate.new(cert_data)
        end
        if user_hash[:user][:'client-key-data']
          key_data = Base64.decode64(user_hash[:user][:'client-key-data'])
          user.client_key = OpenSSL::PKey::RSA.new(key_data)
        end
        @users[user.name] = user
      end
    end

    def parse_contexts
      @contexts = {}
      @config_file[:contexts].each do |context_hash|
        context = Context.new
        context.name = context_hash[:name]
        context.api_version = api_version
        context.cluster = @clusters.fetch(context_hash[:context][:cluster])
        context.user = @users.fetch(context_hash[:context][:user]) if context_hash[:context][:user].present?
        @contexts[context.name] = context
      end
    end

    public

    class User
      attr_accessor :name, :username, :password, :client_cert, :client_key
    end

    class Cluster
      attr_accessor :name, :server, :ca_data

      def url
        server + '/api/'
      end

      def ca_filepath
        @ca_filepath ||= begin
          tmpfile = Tempfile.new(['ca', '.crt'])
          tmpfile.write(Base64.decode64(ca_data))
          tmpfile.close
          tmpfile.path
        end
      end
    end

    class Context
      attr_accessor :name, :cluster, :user, :api_version

      def client
        Kubeclient::Client.new(cluster.url, api_version, ssl_options: ssl_options)
      end

      def ext_client
        Kubeclient::Client.new(cluster.server + '/apis', 'extensions/v1beta1', ssl_options: ssl_options)
      end

      def use_ssl?
        cluster.ca_data.present? && user.client_cert.present?
      end

      def ssl_options
        return {} unless use_ssl?

        {
          client_cert: user.client_cert,
          client_key:  user.client_key,
          ca_file:     cluster.ca_filepath,
          verify_ssl:  OpenSSL::SSL::VERIFY_NONE
        }
      end
    end
  end
end

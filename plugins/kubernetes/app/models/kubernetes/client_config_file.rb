module Kubernetes
  class ClientConfigFile
    attr_reader :config_file, :api_version, :clusters, :users, :contexts

    def initialize(filepath = ENV['KUBE_CONFIG_FILE'])
      filepath ||= "#{ENV.fetch('HOME')}/.kube/config"
      if File.exists?(filepath)
        @config_file = YAML.load_file(filepath).with_indifferent_access
        parse_file
      end
    end

    def exists?
      config_file.present?
    end

    private

    def parse_file
      @api_version = config_file[:apiVerison]
      parse_clusters
      parse_users
      parse_contexts
    end

    def parse_clusters
      @clusters = {}
      config_file[:clusters].each do |cluster_hash|
        cluster = Cluster.new
        cluster.name = cluster_hash[:name]
        cluster.server = cluster_hash[:cluster][:server]
        cluster.ca_data = cluster_hash[:cluster][:'certificate-authority-data']
        @clusters[cluster.name] = cluster
      end
    end

    def parse_users
      @users = {}
      config_file[:users].each do |user_hash|
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
      config_file[:contexts].each do |context_hash|
        context = Context.new
        context.name = context_hash[:name]
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
      attr_accessor :name, :cluster, :user

      def ssl_options
        {
          client_cert: user.client_cert,
          client_key:  user.client_key,
          ca_file:     cluster.ca_filepath,
          verify_ssl:  OpenSSL::SSL::VERIFY_PEER
        }
      end
    end
  end
end
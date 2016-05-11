require 'yaml'
require 'base64'

module Kubeclient
  # Kubernetes client configuration class
  class Config
    # Kubernetes client configuration context class
    class Context
      attr_reader :api_endpoint, :api_version, :ssl_options

      def initialize(api_endpoint, api_version, ssl_options)
        @api_endpoint = api_endpoint
        @api_version = api_version
        @ssl_options = ssl_options
      end
    end

    def initialize(kcfg, kcfg_path)
      @kcfg = kcfg
      @kcfg_path = kcfg_path
      fail 'Unknown kubeconfig version' if @kcfg['apiVersion'] != 'v1'
    end

    def self.read(filename)
      Config.new(YAML.load_file(filename), File.dirname(filename))
    end

    def contexts
      @kcfg['contexts'].map { |x| x['name'] }
    end

    def context(context_name = nil)
      cluster, user = fetch_context(context_name || @kcfg['current-context'])

      ca_cert_data     = fetch_cluster_ca_data(cluster)
      client_cert_data = fetch_user_cert_data(user)
      client_key_data  = fetch_user_key_data(user)

      ssl_options = {}

      if !ca_cert_data.nil?
        cert_store = OpenSSL::X509::Store.new
        cert_store.add_cert(OpenSSL::X509::Certificate.new(ca_cert_data))
        ssl_options[:verify_ssl] = OpenSSL::SSL::VERIFY_PEER
        ssl_options[:cert_store] = cert_store
      else
        ssl_options[:verify_ssl] = OpenSSL::SSL::VERIFY_NONE
      end

      unless client_cert_data.nil?
        ssl_options[:client_cert] = OpenSSL::X509::Certificate.new(client_cert_data)
      end

      unless client_key_data.nil?
        ssl_options[:client_key] = OpenSSL::PKey.read(client_key_data)
      end

      Context.new(cluster['server'], @kcfg['apiVersion'], ssl_options)
    end

    private

    def ext_file_path(path)
      File.join(@kcfg_path, path)
    end

    def fetch_context(context_name)
      context = @kcfg['contexts'].detect do |x|
        break x['context'] if x['name'] == context_name
      end

      fail "Unknown context #{context_name}" unless context

      cluster = @kcfg['clusters'].detect do |x|
        break x['cluster'] if x['name'] == context['cluster']
      end

      fail "Unknown cluster #{context['cluster']}" unless cluster

      user = @kcfg['users'].detect do |x|
        break x['user'] if x['name'] == context['user']
      end || {}

      [cluster, user]
    end

    def fetch_cluster_ca_data(cluster)
      if cluster.key?('certificate-authority')
        return File.read(ext_file_path(cluster['certificate-authority']))
      elsif cluster.key?('certificate-authority-data')
        return Base64.decode64(cluster['certificate-authority-data'])
      end
    end

    def fetch_user_cert_data(user)
      if user.key?('client-certificate')
        return File.read(ext_file_path(user['client-certificate']))
      elsif user.key?('client-certificate-data')
        return Base64.decode64(user['client-certificate-data'])
      end
    end

    def fetch_user_key_data(user)
      if user.key?('client-key')
        return File.read(ext_file_path(user['client-key']))
      elsif user.key?('client-key-data')
        return Base64.decode64(user['client-key-data'])
      end
    end
  end
end

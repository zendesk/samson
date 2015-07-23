require 'kubeclient'

class Kubernetes

  # NOTE: At the moment, this client assumes that a config file exists at
  # ~/.kube/config, which gets created if you're running kubernetes with
  # Vagrant.  We'll need to update this logic to allow passing in the
  # same information through ENV variables.
  def self.client
    @current ||= begin
      Kubeclient::Client.new("#{config_file[:clusters].first[:cluster][:server]}/api/", 'v1', ssl_options: ssl_options)
    end
  end

  def self.config_file
    @config_file ||= YAML.load_file("#{ENV.fetch('HOME')}/.kube/config").with_indifferent_access
  end

  def self.ssl_options
    @ssl_options ||= begin
      {
        client_cert: OpenSSL::X509::Certificate.new(client_cert),
        client_key:  OpenSSL::PKey::RSA.new(client_key),
        ca_file:     ca_filepath,
        verify_ssl:  OpenSSL::SSL::VERIFY_PEER
      }
    end
  end

  def self.client_cert
    @client_cert ||= Base64.decode64(config_file[:users].first[:user][:'client-certificate-data'])
  end

  def self.client_key
    @client_key ||= Base64.decode64(config_file[:users].first[:user][:'client-key-data'])
  end

  def self.ca_filepath
    @ca_filepath ||= begin
      filepath = "#{ENV.fetch('HOME')}/.kube/ca.crt"
      File.write(filepath, Base64.decode64(config_file[:clusters].first[:cluster][:'certificate-authority-data']))
      filepath
    end
  end
end

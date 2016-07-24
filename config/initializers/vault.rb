if ENV["SECRET_STORAGE_BACKEND"] == "SecretStorage::HashicorpVault"
  require 'vault'
  Rails.logger.info("Vault Client enabled")

  # Assumes that a vault.json file exists which contains an array of hashes.
  # Each hash represents an Vault instance Samson can connect to.
  # The attributes of the hash are:
  #   - vault_address (string, required) - URL of the vault host
  #   - deploy_groups (Array, required) - list of deploy groups for that Vault
  #   - ca_cert (string) - path to CA cert used to verify the Vault server cert
  #   - vault_token (string) - path to file containing an auth token
  #   - vault_auth_pem (string) - path to file containing a client certificate
  #   - tls_verify (boolean) - whether to verify the server's cert

  class VaultClient < Vault::Client
    CERT_AUTH_PATH = '/v1/auth/cert/login'.freeze
    DEFAULT_CLIENT_OPTIONS = {
      use_ssl: true,
      timeout: 5,
      ssl_timeout: 3,
      open_timeout: 3,
      read_timeout: 2
    }.freeze

    def self.auth_token(vault_server)
      uri = URI.parse(vault_server)
      @http = Net::HTTP.start(uri.host, uri.port, DEFAULT_CLIENT_OPTIONS)
      response = @http.request(Net::HTTP::Post.new(CERT_AUTH_PATH))
      if response.code == "200"
        JSON.parse(response.body).fetch("auth")["client_token"]
      else
        raise "Failed to get auth token from vault server"
      end
    end

    def self.client
      @client ||= new
    end

    def initialize
      return if Rails.env.test?
      ensure_config_exists
      # since we have a bunch of servers, don't use the client singlton to
      # talk to them
      # as we configure each client, check to see if the config has a token in it,
      # if it does, then we don't need to worry about going and getting one
      @writers = vault_hosts.map do |vault_server|
        if vault_server["vault_token"].present?
          writer = Vault::Client.new(DEFAULT_CLIENT_OPTIONS.merge(verify_mode: vault_server["tls_verify"]))
          writer.token = File.read(vault_server["vault_token"]).strip
        else
          pemfile = File.read(vault_server["vault_auth_pem"])
          client_cert_options = {
            cert: OpenSSL::X509::Certificate.new(pemfile),
            key: OpenSSL::PKey::RSA.new(pemfile),
            ssl_pem_file: vault_server["vault_auth_pem"],
            verify_mode: vault_server["tls_verify"]
          }
          writer = Vault::Client.new(DEFAULT_CLIENT_OPTIONS.merge(client_cert_options))
          writer.token = VaultClient.auth_token(vault_server["vault_address"])
        end
        writer.address = vault_server["vault_address"]
        writer.ssl_ca_cert = vault_server["ca_cert"] if vault_server["ca_cert"]
        writer
      end
      @reader = @writers.first
    end

    def read(key)
      @reader.logical.read(key)
    end

    def list(path)
      @reader.logical.list(path)
    end

    # make darn sure on deletes and writes that we try a couple of times.
    # not going to catch any other excpeptions as we want this to blow up
    # if anything fails
    def write(key, data)
      @writers.each do |vault_server|
        Vault.with_retries(Vault::HTTPConnectionError, attempts: 5) do
          vault_server.logical.write(key, data)
        end
      end
    end

    def delete(key)
      @writers.each do |vault_server|
        Vault.with_retries(Vault::HTTPConnectionError, attempts: 5) do
          vault_server.logical.delete(key)
        end
      end
    end

    def config_for(deploy_group_name)
      vault_hosts.detect do |hash|
        hash.fetch('deploy_groups', []).include? deploy_group_name
      end
    end

    private

    def ensure_config_exists
      unless File.exist?(vault_config_file)
        raise "VAULT_CONFIG_FILE or config/vault.json is required for #{ENV["SECRET_STORAGE_BACKEND"]}"
      end
    end

    def vault_hosts
      @vault_hosts ||= JSON.parse(File.read(vault_config_file))
    end

    def vault_config_file
      ENV['VAULT_CONFIG_FILE'] || Rails.root.join("config/vault.json")
    end
  end
end

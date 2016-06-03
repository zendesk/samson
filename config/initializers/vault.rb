if ENV["SECRET_STORAGE_BACKEND"] == "SecretStorage::HashicorpVault"
  require 'vault'
  Rails.logger.info("Vault Client enabled")

  class VaultClient < Vault::Client
    PEM = File.read(Vault.ssl_pem_file)
    CERT_AUTH_PATH = '/v1/auth/cert/login'.freeze
    DEFAULT_CLIENT_OPTIONS = {
      use_ssl: true,
      ssl_pem_file: Rails.root.join(ENV.fetch("VAULT_SSL_CERT")),
      verify_mode: ENV.fetch("VAULT_SSL_VERIFY", 1).to_i,
      timeout: 5,
      ssl_timeout: 3,
      open_timeout: 3,
      read_timeout: 2,
      cert: OpenSSL::X509::Certificate.new(PEM),
      key: OpenSSL::PKey::RSA.new(PEM)
    }.freeze

    def initialize
      return if Rails.env.test?
      # since we have a bunch of servers, don't use the client singlton to
      # talk to them
      @writers = vault_hosts.map do |vault_server|
        writer = Vault::Client.new(DEFAULT_CLIENT_OPTIONS)
        writer.address = vault_server
        writer.token = VaultClient.auth_token(vault_server)
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

    private

    def vault_hosts
      ENV.fetch("VAULT_ADDR").split(/[\s,]+/)
    end
  end
end

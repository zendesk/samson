VAULT_CONFIG = Rails.application.config_for(:vault).symbolize_keys.freeze
if ENV["SECRET_STORAGE_BACKEND"] == "SecretStorage::HashicorpVault"
  require 'vault'
  Rails.logger.info("Vault Client enabled")
  Vault.configure do |config|
    config.ssl_pem_file = Rails.root.join(VAULT_CONFIG.fetch(:pem_path))
    config.ssl_verify = ActiveRecord::Type::Boolean.new.type_cast_from_user(VAULT_CONFIG[:ssl_verify])

    # Timeout the connection after a certain amount of time (seconds)
    config.timeout = 5

    # It is also possible to have finer-grained controls over the timeouts, these
    # may also be read as environment variables
    config.ssl_timeout  = 3
    config.open_timeout = 3
    config.read_timeout = 2
  end

  # build our own client here so we can write to multiple
  # vaults based on env
  class VaultClient < Vault::Client
    PEM = File.read(Vault.ssl_pem_file)
    CERT_AUTH_PATH = '/v1/auth/cert/login'.freeze
    DEFAULT_CLIENT_OPTIONS = {
      use_ssl: true,
      verify_mode: ENV.fetch("VAULT_SSL_VERIFY", 1).to_i,
      cert: OpenSSL::X509::Certificate.new(PEM),
      key: OpenSSL::PKey::RSA.new(PEM)
    }.freeze

    def initialize
      # we are just stubbing in our own auth, everything else should fall
      # through to our parrent
      super

      # if we are testing, just return here.  We'll let super configure
      # the rest of the client
      return if Rails.env.test?
      uri = URI.parse(vault_host)
      @http = Net::HTTP.start(uri.host, uri.port, DEFAULT_CLIENT_OPTIONS)
      response = @http.request(Net::HTTP::Post.new(CERT_AUTH_PATH))
      if response.code == "200"
        @token = JSON.parse(response.body).fetch("auth")["client_token"]
      else
        raise "Failed to get auth token from vault server"
      end
    end

    def read(key)
      Vault.address = vault_host
      Vault.logical.read(key)
    end

    def list(path)
      Vault.address = vault_host
      Vault.logical.list(path)
    end

    # make darn sure on deletes and writes that we try a couple of times.
    def write(key, data)
      vault_hosts.each do |vault_server|
        Vault.address = vault_server
        Vault.with_retries(Vault::HTTPConnectionError, attempts: 5) do
          Vault.logical.write(key, data)
        end
      end
    end

    def delete(key)
      vault_hosts.each do |vault_server|
        Vault.address = vault_server
        Vault.with_retries(Vault::HTTPConnectionError, attempts: 5) do
          Vault.logical.delete(key)
        end
      end
    end

    def vault_host
      vault_hosts.first
    end

    def vault_hosts
      VAULT_CONFIG.fetch(:hosts).split(/[\s,]+/)
    end
  end
end

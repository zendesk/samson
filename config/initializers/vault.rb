VAULT_ENABLED = ENV.fetch('SECRET_STORAGE_BACKEND', false)
if VAULT_ENABLED == 'SecretStorage::HashicorpVault'
  require 'vault'
  Rails.logger.info("Vault Client enabled")
  Vault.configure do |config|
    config.ssl_pem_file = ENV.fetch("VAULT_SSL_CERT")
    config.ssl_verify = ActiveRecord::Type::Boolean.new.type_cast_from_user(ENV.fetch("VAULT_SSL_VERIFY", true))
    config.address = ENV.fetch("VAULT_ADDR", 'https://127.0.0.1:8200')

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
    CERT_AUTH_PATH =  '/v1/auth/cert/login'.freeze
    DEFAULT_CLIENT_OPTIONS = {
      use_ssl: true,
      verify_mode: 0,
      cert: OpenSSL::X509::Certificate.new(PEM),
      key: OpenSSL::PKey::RSA.new(PEM)
    }

    def initialize
      # we are just stubbing in our own auth, everything else should fall
      # through to our parrent
      super
      uri = URI.parse(Vault.address)
      @http = Net::HTTP.start(uri.host, uri.port, DEFAULT_CLIENT_OPTIONS)
      response = @http.request(Net::HTTP::Post.new(CERT_AUTH_PATH))
      if (response.code.to_i == 200)
        @token = JSON.parse(response.body).delete("auth")["client_token"]
      else
        raise "Missing Token"
      end
    end
  end
end

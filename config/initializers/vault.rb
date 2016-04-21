VAULT_ENABLED = ENV.fetch('SECRET_STORAGE_BACKEND', false)
if VAULT_ENABLED == 'SecretStorage::HashicorpVault'
  require 'vault'
  Rails.logger.info("Vault Client enabled")
  Vault.configure do |config|
    config.ssl_pem_file = ENV.fetch("VAULT_SSL_CERT")
    config.ssl_verify = ActiveRecord::Type::Boolean.new.type_cast_from_user(ENV.fetch("VAULT_SSL_VERIFY", true))
    config.address = ENV.fetch("VAULT_ADDR", 'https://127.0.0.1:8200')

    # Timeout the connection after a certain amount of time (seconds), also read
    config.timeout = 30

    # It is also possible to have finer-grained controls over the timeouts, these
    # may also be read as environment variables
    config.ssl_timeout  = 5
    config.open_timeout = 5
    config.read_timeout = 30
  end
end

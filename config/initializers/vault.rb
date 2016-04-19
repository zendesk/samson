VAULT_ENABLED = ENV.fetch("VAULT_ENABLED")
if VAULT_ENABLED
  require 'vault'
  Rails.logger.info("Enabling the vault client")
  Vault.configure do |config|
    # Custom SSL PEM, also read as ENV["VAULT_SSL_CERT"]
    config.ssl_pem_file = "#{Rails.root}/config/samson.pem"

    # Use SSL verification, also read as ENV["VAULT_SSL_VERIFY"]
    config.ssl_verify = false

    # Timeout the connection after a certain amount of time (seconds), also read
    # as ENV["VAULT_TIMEOUT"]
    config.timeout = 30

    # It is also possible to have finer-grained controls over the timeouts, these
    # may also be read as environment variables
    config.ssl_timeout  = 5
    config.open_timeout = 5
    config.read_timeout = 30
  end
end

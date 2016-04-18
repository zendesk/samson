require 'vault'

Vault.configure do |config|
  # The address of the Vault server, also read as ENV["VAULT_ADDR"]
  config.address = "https://127.0.0.1:8200"

  # The token to authenticate with Vault, also read as ENV["VAULT_TOKEN"]
  config.token = "abcd-1234"

  # Proxy connection information, also read as ENV["VAULT_PROXY_(thing)"]
  config.proxy_address  = "..."
  config.proxy_port     = "..."
  config.proxy_username = "..."
  config.proxy_password = "..."

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


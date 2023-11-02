module Vault
  class VaultError < RuntimeError; end

  class MissingTokenError < VaultError
    def initialize
      super <<-EOH
Missing Vault token! I cannot make requests to Vault without a token. Please
set a Vault token in the client:

    Vault.token = "42d1dee5-eb6e-102c-8d23-cc3ba875da51"

or authenticate with Vault using the Vault CLI:

    $ vault auth ...

or set the environment variable $VAULT_TOKEN to the token value:

    $ export VAULT_TOKEN="..."

Please refer to the documentation for more examples.
EOH
    end
  end

  class HTTPConnectionError < VaultError
    attr_reader :address

    def initialize(address, exception)
      @address = address
      @exception = exception

      super <<-EOH
The Vault server at `#{address}' is not currently
accepting connections. Please ensure that the server is running and that your
authentication information is correct.

The original error was `#{exception.class}'. Additional information (if any) is
shown below:

    #{exception.message}

Please refer to the documentation for more help.
EOH
    end

    def original_exception
      @exception
    end
  end

  class HTTPError < VaultError
    attr_reader :address, :response, :code, :errors

    def initialize(address, response, errors = [])
      @address, @response, @errors = address, response, errors
      @code  = response.code.to_i
      errors = errors.map { |error| "  * #{error}" }

      super <<-EOH
The Vault server at `#{address}' responded with a #{code}.
Any additional information the server supplied is shown below:

#{errors.join("\n").rstrip}

Please refer to the documentation for help.
EOH
    end
  end

  class HTTPClientError < HTTPError; end
  class HTTPServerError < HTTPError; end
end

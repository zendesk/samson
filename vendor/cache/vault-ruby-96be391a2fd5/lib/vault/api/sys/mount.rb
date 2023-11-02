require "json"

module Vault
  class Mount < Response
    # @!attribute [r] config
    #   Arbitrary configuration for the backend.
    #   @return [Hash<Symbol, Object>]
    field :config

    # @!attribute [r] description
    #   Description of the mount.
    #   @return [String]
    field :description

    # @!attribute [r] type
    #   Type of the mount.
    #   @return [String]
    field :type
  end

  class Sys < Request
    # List all mounts in the vault.
    #
    # @example
    #   Vault.sys.mounts #=> { :secret => #<struct Vault::Mount type="generic", description="generic secret storage"> }
    #
    # @return [Hash<Symbol, Mount>]
    def mounts
      json = client.get("/v1/sys/mounts")
      json = json[:data] if json[:data]
      return Hash[*json.map do |k,v|
        [k.to_s.chomp("/").to_sym, Mount.decode(v)]
      end.flatten]
    end

    # Create a mount at the given path.
    #
    # @example
    #   Vault.sys.mount("pg", "postgresql", "Postgres user management") #=> true
    #
    # @param [String] path
    #   the path to mount at
    # @param [String] type
    #   the type of mount
    # @param [String] description
    #   a human-friendly description (optional)
    def mount(path, type, description = nil, options = {})
      payload = options.merge type: type
      payload[:description] = description if !description.nil?

      client.post("/v1/sys/mounts/#{encode_path(path)}", JSON.fast_generate(payload))
      return true
    end

    # Tune a mount at the given path.
    #
    # @example
    #   Vault.sys.mount_tune("pki", max_lease_ttl: '87600h') #=> true
    #
    # @param [String] path
    #   the path to write
    # @param [Hash] data
    #   the data to write
    def mount_tune(path, data = {})
      json = client.post("/v1/sys/mounts/#{encode_path(path)}/tune", JSON.fast_generate(data))
      return true
    end

    # Unmount the thing at the given path. If the mount does not exist, an error
    # will be raised.
    #
    # @example
    #   Vault.sys.unmount("pg") #=> true
    #
    # @param [String] path
    #   the path to unmount
    #
    # @return [true]
    def unmount(path)
      client.delete("/v1/sys/mounts/#{encode_path(path)}")
      return true
    end

    # Change the name of the mount
    #
    # @example
    #   Vault.sys.remount("pg", "postgres") #=> true
    #
    # @param [String] from
    #   the origin mount path
    # @param [String] to
    #   the new mount path
    #
    # @return [true]
    def remount(from, to)
      client.post("/v1/sys/remount", JSON.fast_generate(
        from: from,
        to:   to,
      ))
      return true
    end
  end
end

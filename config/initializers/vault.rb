# frozen_string_literal: true
# instrument all vault calls
require 'vault'

Vault::Client.prepend(
  Module.new do
    def request(method, path, *)
      ActiveSupport::Notifications.instrument("request.vault.samson", method: method, path: path) { super }
    end
  end
)

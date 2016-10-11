# frozen_string_literal: true
module Samson
  module Secrets
    # making url generation from models work by changing
    # samson_secrets_vault_server_path -> vault_server_path
    def self.use_relative_model_naming?
      true
    end
  end
end

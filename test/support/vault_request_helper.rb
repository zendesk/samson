# frozen_string_literal: true
module VaultRequestHelper
  def self.included(base)
    base.before do
      Samson::Secrets::VaultClientManager.class_eval { @instance = nil } # build a new manager each time
      deploy_groups(:pod2).update_column(:vault_server_id, create_vault_server.id)
    end
  end

  def assert_vault_request(method, path, versioned_kv: false, address: "http://vault-land.com", **options, &block)
    options[:to_return] = {
      headers: options.delete(:headers) || {content_type: 'application/json'}, # does not parse json without
      body: options.delete(:body) || "{}", # errors need a basic response too
      status: options.delete(:status) || 200
    }
    url = (versioned_kv ? "#{address}/v1/secret/#{versioned_kv}/apps/#{path}" : "#{address}/v1/secret/apps/#{path}")
    assert_request(method, url, options, &block)
  end
end

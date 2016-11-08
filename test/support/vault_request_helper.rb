# frozen_string_literal: true
module VaultRequestHelper
  def self.included(base)
    base.before do
      Samson::Secrets::VaultServer.any_instance.stubs(:validate_connection)
      Samson::Secrets::VaultClient.class_eval { @client = nil } # bust client cache so we build a new one each time
      server = Samson::Secrets::VaultServer.create!(name: 'pod2', address: 'http://vault-land.com', token: 'TOKEN')
      deploy_groups(:pod2).update_column(:vault_server_id, server.id)
    end
  end

  def assert_vault_request(method, path, response = {})
    with = response.delete(:with)
    response[:headers] ||= {content_type: 'application/json'} # does not parse json without
    response[:body] ||= "{}" # errors need a basic response too
    times = response.delete(:times) || 1

    # make calling code easy to read by not having to encode keys
    request = stub_request(method, "http://vault-land.com/v1/secret/apps/#{path}")
    request = request.with(with) if with
    request = request.to_return(response)

    yield # no ensure, so it does not fail when we already blew up

    assert_requested request, times: times
  end
end

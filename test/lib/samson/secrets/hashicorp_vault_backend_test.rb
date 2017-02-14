# frozen_string_literal: true
require_relative '../../../test_helper'

SingleCov.covered!

describe Samson::Secrets::HashicorpVaultBackend do
  include VaultRequestHelper

  describe ".read" do
    it "reads" do
      assert_vault_request :get, "production/foo/pod2/bar", body: {data: { vault: "SECRET"}}.to_json do
        Samson::Secrets::HashicorpVaultBackend.read('production/foo/pod2/bar').must_equal(
          auth: nil,
          lease_duration: nil,
          lease_id: nil,
          renewable: nil,
          warnings: nil,
          wrap_info: nil,
          value: "SECRET"
        )
      end
    end

    it "returns nil when it fails to read" do
      assert_vault_request :get, "production/foo/pod2/bar", status: 404 do
        Samson::Secrets::HashicorpVaultBackend.read('production/foo/pod2/bar').must_be_nil
      end
    end

    it "returns nil when trying to read nil" do
      Samson::Secrets::HashicorpVaultBackend.read(nil).must_be_nil
    end

    it "raises when trying to read an invalid path so it behaves like a database backend" do
      assert_raises ActiveRecord::RecordNotFound do
        Samson::Secrets::HashicorpVaultBackend.read("wut")
      end
    end
  end

  describe ".read_multi" do
    it "returns values as hash" do
      assert_vault_request :get, "production/foo/pod2/bar", body: {data: { vault: "SECRET"}}.to_json do
        Samson::Secrets::HashicorpVaultBackend.read_multi(['production/foo/pod2/bar']).must_equal(
          'production/foo/pod2/bar' => {
            auth: nil,
            lease_duration: nil,
            lease_id: nil,
            renewable: nil,
            warnings: nil,
            wrap_info: nil,
            value: "SECRET"
          }
        )
      end
    end

    it "leaves out unfound values" do
      assert_vault_request :get, "production/foo/pod2/bar", status: 404 do
        Samson::Secrets::HashicorpVaultBackend.read_multi(['production/foo/pod2/bar']).must_equal({})
      end
    end

    it "leaves out vaules from deploy groups that have no vault server so KeyResolver works" do
      Samson::Secrets::HashicorpVaultBackend.read_multi(['production/foo/pod100/bar']).must_equal({})
    end
  end

  describe ".delete" do
    it "deletes" do
      assert_vault_request :delete, "production/foo/pod2/bar" do
        assert Samson::Secrets::HashicorpVaultBackend.delete('production/foo/pod2/bar')
      end
    end
  end

  describe ".write" do
    it "writes" do
      data = {vault: "whatever", visible: false, comment: "secret!", creator_id: 1, updater_id: 1}
      assert_vault_request :get, "production/foo/pod2/bar", status: 404 do
        assert_vault_request :put, "production/foo/pod2/bar", with: {body: data.to_json} do
          assert Samson::Secrets::HashicorpVaultBackend.write(
            'production/foo/pod2/bar', value: 'whatever', visible: false, user_id: 1, comment: 'secret!'
          )
        end
      end
    end

    it "updates without changing the creator" do
      data = {vault: "whatever", visible: true, comment: "secret!", creator_id: 2, updater_id: 1}
      assert_vault_request :get, "production/foo/pod2/bar", body: {data: {creator_id: 2, vault: "old"}}.to_json do
        assert_vault_request :put, "production/foo/pod2/bar", with: {body: data.to_json} do
          assert Samson::Secrets::HashicorpVaultBackend.write(
            'production/foo/pod2/bar', value: 'whatever', visible: true, user_id: 1, comment: 'secret!'
          )
        end
      end
    end
  end

  describe ".keys" do
    it "lists all keys with recursion" do
      first_keys = {data: {keys: ["production/project/group/this/", "production/project/group/that/"]}}
      sub_key = {data: {keys: ["key"]}}

      assert_vault_request :get, "?list=true", body: first_keys.to_json do
        assert_vault_request :get, "production/project/group/this/?list=true", body: sub_key.to_json do
          assert_vault_request :get, "production/project/group/that/?list=true", body: sub_key.to_json do
            Samson::Secrets::HashicorpVaultBackend.keys.must_equal(
              [
                "production/project/group/this/key",
                "production/project/group/that/key"
              ]
            )
          end
        end
      end
    end
  end

  describe "raises BackendError when a vault instance is down/unreachable" do
    let(:client) { Samson::Secrets::VaultClient.client }

    it ".keys" do
      client.expects(:list_recursive).
        raises(Vault::HTTPConnectionError.new("address", RuntimeError.new('no keys for you')))
      e = assert_raises Samson::Secrets::BackendError do
        Samson::Secrets::HashicorpVaultBackend.keys
      end
      e.message.must_include('no keys for you')
    end

    it ".read" do
      client.expects(:read).raises(Vault::HTTPConnectionError.new("address", RuntimeError.new('no read for you')))
      e = assert_raises Samson::Secrets::BackendError do
        Samson::Secrets::HashicorpVaultBackend.read('production/foo/group/isbar/foo')
      end
      e.message.must_include('no read for you')
    end

    it ".write" do
      client.expects(:read).returns(nil)
      client.expects(:write).raises(Vault::HTTPConnectionError.new("address", RuntimeError.new('no write for you')))
      e = assert_raises Samson::Secrets::BackendError do
        Samson::Secrets::HashicorpVaultBackend.write(
          'production/foo/group/isbar/foo', value: 'whatever', visible: false, user_id: 1, comment: 'secret!'
        )
      end
      e.message.must_include('no write for you')
    end
  end

  describe ".convert_path" do
    it "fails with invalid direction" do
      assert_raises ArgumentError do
        Samson::Secrets::HashicorpVaultBackend.send(:convert_path, 'x', :ooops)
      end
    end
  end
end

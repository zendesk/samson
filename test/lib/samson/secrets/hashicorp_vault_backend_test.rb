# frozen_string_literal: true
require_relative '../../../test_helper'

SingleCov.covered!

describe Samson::Secrets::HashicorpVaultBackend do
  include VaultRequestHelper

  let(:backend) { Samson::Secrets::HashicorpVaultBackend }

  it "keeps segments in sync with storage" do
    Samson::Secrets::HashicorpVaultBackend::ID_SEGMENTS.must_equal Samson::Secrets::Manager::ID_PARTS.size
  end

  describe ".read" do
    it "reads" do
      assert_vault_request :get, "production/foo/pod2/bar", body: {data: {vault: "SECRET"}}.to_json do
        backend.read('production/foo/pod2/bar').must_equal(
          auth: nil,
          metadata: nil,
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
        backend.read('production/foo/pod2/bar').must_be_nil
      end
    end

    it "returns nil when trying to read nil" do
      backend.read(nil).must_be_nil
    end

    it "raises when trying to read an invalid path so it behaves like a database backend" do
      assert_raises ActiveRecord::RecordNotFound do
        backend.read("wut")
      end
    end
  end

  describe ".history" do
    before { Samson::Secrets::VaultServer.update_all(versioned_kv: true) }

    it "reads simple" do
      versions_body = {data: {foo: "bar", versions: {}}}
      assert_vault_request :get, "production/foo/pod2/bar", versioned_kv: "metadata", body: versions_body.to_json do
        backend.history('production/foo/pod2/bar').must_equal(foo: "bar", versions: {})
      end
    end

    it "ignores missing" do
      assert_vault_request :get, "production/foo/pod2/bar", versioned_kv: "metadata", status: 404 do
        backend.history('production/foo/pod2/bar').must_be_nil
      end
    end

    it "does not resolve versions by default" do
      id = "production/foo/pod2/bar"
      versions_body = {data: {versions: {"v1" => {foo: "bar"}}}}
      assert_vault_request :get, id, versioned_kv: "metadata", body: versions_body.to_json do
        result = backend.history('production/foo/pod2/bar')
        result[:versions].each_value { |item| item.delete_if { |_, v| v.nil? } }
        result.must_equal versions: {v1: {foo: "bar"}}
      end
    end

    it "resolves versions" do
      id = "production/foo/pod2/bar"
      versions_body = {data: {versions: {"v1" => {foo: "bar"}}}}
      version_body = {data: {data: {vault: 1}, metadata: {v1: 1}}}
      assert_vault_request :get, id, versioned_kv: "metadata", body: versions_body.to_json do
        assert_vault_request :get, "#{id}?version=v1", versioned_kv: "data", body: version_body.to_json do
          result = backend.history('production/foo/pod2/bar', resolve: true)
          result[:versions].each_value { |item| item.delete_if { |_, v| v.nil? } }
          result.must_equal versions: {v1: {metadata: {v1: 1}, value: 1}}
        end
      end
    end

    it "does not resolve unrecoverable versions" do
      id = "production/foo/pod2/bar"
      versions_body = {data: {versions: {"v1" => {foo: "bar", destroyed: true}}}}
      assert_vault_request :get, id, versioned_kv: "metadata", body: versions_body.to_json do
        result = backend.history('production/foo/pod2/bar', resolve: true)
        result.must_equal versions: {v1: {metadata: {foo: "bar", destroyed: true}}}
      end
    end

    it "does not resolve deleted versions" do
      id = "production/foo/pod2/bar"
      versions_body = {data: {versions: {
        "v1" => {foo: "bar", destroyed: false, deletion_time: "2019-10-29"},
        "v2" => {foo: "bar2", destroyed: false, deletion_time: ""}
      }}}
      version_body = {data: {data: {vault: 1}, metadata: {v2: {metadata: {foo: "bar2", destroyed: false}}}}}
      assert_vault_request :get, id, versioned_kv: "metadata", body: versions_body.to_json do
        assert_vault_request :get, "#{id}?version=v2", versioned_kv: "data", body: version_body.to_json do
          result = backend.history('production/foo/pod2/bar', resolve: true)
          result.must_equal versions: {
            v1: {metadata: {foo: "bar", destroyed: false, deletion_time: "2019-10-29"}},
            v2: {
              metadata: {
                v2: {metadata: {foo: "bar2", destroyed: false}}
              },
              auth: nil, lease_duration: nil, lease_id: nil, renewable: nil, warnings: nil, wrap_info: nil, value: 1
            }
          }
        end
      end
    end
  end

  describe ".read_multi" do
    it "returns values as hash" do
      assert_vault_request :get, "production/foo/pod2/bar", body: {data: {vault: "SECRET"}}.to_json do
        backend.read_multi(['production/foo/pod2/bar']).must_equal(
          'production/foo/pod2/bar' => {
            auth: nil,
            metadata: nil,
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
        backend.read_multi(['production/foo/pod2/bar']).must_equal({})
      end
    end

    it "raises an error if client is not authorized" do
      assert_raises Vault::HTTPClientError do
        assert_vault_request :get, "production/foo/pod2/bar", status: 403 do
          backend.read_multi(['production/foo/pod2/bar'])
        end
      end
    end

    it "leaves out values from deploy groups that have no vault server so KeyResolver works" do
      backend.read_multi(['production/foo/pod100/bar']).must_equal({})
    end

    it "leaves out values from unknown deploy groups" do
      backend.read_multi(['production/foo/pod1nope/bar']).must_equal({})
    end
  end

  describe ".delete" do
    it "deletes" do
      assert_vault_request :delete, "production/foo/pod2/bar" do
        assert backend.delete('production/foo/pod2/bar')
      end
    end
  end

  describe ".write" do
    let(:data) { {vault: "whatever", visible: false, comment: "secret!", creator_id: 1, updater_id: 1} }
    let(:old_data) { data.merge(vault: "old") }

    it "creates" do
      assert_vault_request :get, "production/foo/pod2/bar", status: 404 do
        assert_vault_request :put, "production/foo/pod2/bar", with: {body: data.to_json} do
          assert backend.write(
            'production/foo/pod2/bar', value: 'whatever', visible: false, user_id: 1, comment: 'secret!'
          )
        end
      end
    end

    it "updates without changing the creator" do
      data[:creator_id] = 2 # testing that creator does not get changed to user_id
      data[:visible] = true # testing that we can set true too
      assert_vault_request :get, "production/foo/pod2/bar", body: {data: old_data}.to_json do
        assert_vault_request :put, "production/foo/pod2/bar", with: {body: data.to_json} do
          assert backend.write(
            'production/foo/pod2/bar', value: 'whatever', visible: true, user_id: 1, comment: 'secret!'
          )
        end
      end
    end

    it "reverts when it could not update" do
      assert_raises Vault::HTTPServerError do
        assert_vault_request :get, "production/foo/pod2/bar", body: {data: old_data}.to_json do
          assert_vault_request :put, "production/foo/pod2/bar", with: {body: data.to_json}, status: 500 do
            assert_vault_request :put, "production/foo/pod2/bar", with: {body: old_data.to_json} do
              assert backend.write(
                'production/foo/pod2/bar', value: 'whatever', visible: false, user_id: 1, comment: 'secret!'
              )
            end
          end
        end
      end
    end

    it "reverts when it could not create" do
      assert_raises Vault::HTTPServerError do
        assert_vault_request :get, "production/foo/pod2/bar", status: 404 do
          assert_vault_request :put, "production/foo/pod2/bar", with: {body: data.to_json}, status: 500 do
            assert_vault_request :delete, "production/foo/pod2/bar" do
              assert backend.write(
                'production/foo/pod2/bar', value: 'whatever', visible: false, user_id: 1, comment: 'secret!'
              )
            end
          end
        end
      end
    end
  end

  describe ".ids" do
    it "lists all ids with recursion" do
      first_ids = {data: {keys: ["production/project/group/this/", "production/project/group/that/"]}}
      sub_id = {data: {keys: ["id1"]}}

      assert_vault_request :get, "?list=true", body: first_ids.to_json do
        assert_vault_request :get, "production/project/group/this/?list=true", body: sub_id.to_json do
          assert_vault_request :get, "production/project/group/that/?list=true", body: sub_id.to_json do
            backend.ids.must_equal(
              [
                "production/project/group/this/id1",
                "production/project/group/that/id1"
              ]
            )
          end
        end
      end
    end

    it "ignores invalid ids so a single bad key does not blow up secrets UI" do
      Samson::ErrorNotifier.expects(:notify)
      assert_vault_request :get, "?list=true", body: {data: {keys: ["oh-noes", "a/b/c/d"]}}.to_json do
        backend.ids.must_equal ["a/b/c/d"]
      end
    end
  end

  describe "raises BackendError when a vault instance is down/unreachable" do
    let(:manager) { Samson::Secrets::VaultClientManager.instance }

    it ".ids" do
      manager.expects(:list_recursive).
        raises(Vault::HTTPConnectionError.new("address", RuntimeError.new('no ids for you')))
      e = assert_raises Samson::Secrets::BackendError do
        backend.ids
      end
      e.message.must_include('no ids for you')
    end

    it ".read" do
      manager.expects(:read).raises(Vault::HTTPConnectionError.new("address", RuntimeError.new('no read for you')))
      e = assert_raises Samson::Secrets::BackendError do
        backend.read('production/foo/group/isbar/foo')
      end
      e.message.must_include('no read for you')
    end

    it ".write" do
      manager.expects(:read).returns(nil) # does not exist -> create
      # tries to revert after failure ... but also fails
      manager.expects(:delete).
        raises(Vault::HTTPConnectionError.new("address", RuntimeError.new('no delete for you')))
      manager.expects(:write).
        raises(Vault::HTTPConnectionError.new("address", RuntimeError.new('no write for you')))

      e = assert_raises Samson::Secrets::BackendError do
        backend.write(
          'production/foo/group/isbar/foo', value: 'whatever', visible: false, user_id: 1, comment: 'secret!'
        )
      end
      e.message.must_include('no write for you')
    end
  end

  describe ".convert_path" do
    it "fails with invalid direction" do
      assert_raises ArgumentError do
        backend.send(:convert_path!, 'x', :ooops)
      end
    end
  end

  describe ".deploy_groups" do
    it "does not include ones that could not be selected" do
      backend.deploy_groups.must_equal [deploy_groups(:pod2)]
    end
  end
end

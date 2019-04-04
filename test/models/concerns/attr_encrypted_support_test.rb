# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe AttrEncryptedSupport do
  let(:secret) { create_secret 'production/foo/pod2/hello' }

  describe "#store_encryption_key_sha" do
    it "stores the encryption key sha so we can rotate it in the future" do
      secret.encryption_key_sha.must_equal "c975b468c4677aa69a20769bf9553ea1937b84684c2876130f9c528731963f4d"
    end
  end

  describe "#as_json" do
    it "does not include encrypted attributes" do
      secret.as_json.keys.must_equal(
        ["id", "updater_id", "creator_id", "created_at", "updated_at", "visible", "comment", "deprecated_at"]
      )
    end

    it "does not include user supplied excepts" do
      secret.as_json(except: [:creator_id]).keys.must_equal(
        ["id", "updater_id", "created_at", "updated_at", "visible", "comment", "deprecated_at"]
      )
    end

    it "does not change user supplied excepts" do
      except = [:name]
      secret.as_json(except: except)
      except.must_equal [:name]
    end
  end
end

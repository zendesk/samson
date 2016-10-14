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
end

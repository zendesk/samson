# frozen_string_literal: true
require_relative '../../../test_helper'

SingleCov.covered!

describe Samson::Secrets::DbBackend do
  let(:secret) { create_secret 'production/foo/pod2/hello' }

  describe ".read" do
    it "reads" do
      Samson::Secrets::DbBackend.read(secret.id)[:value].must_equal 'MY-SECRET'
    end

    it "returns nil when it cannot find" do
      Samson::Secrets::DbBackend.read('production/foo/pod2/noooo').must_equal nil
    end
  end

  describe ".read_multi" do
    it "reads" do
      read = Samson::Secrets::DbBackend.read_multi([secret.id])
      read.map { |k, s| [k, s[:value]] }.must_equal [[secret.id, 'MY-SECRET']]
    end

    it "returns nothing when it cannot find" do
      Samson::Secrets::DbBackend.read_multi('production/foo/pod2/noooo').must_equal({})
    end
  end

  describe ".keys" do
    it "returns all keys" do
      secret # trigger create
      Samson::Secrets::DbBackend.keys.must_equal [secret.id]
    end
  end

  describe ".delete" do
    it "deletes" do
      Samson::Secrets::DbBackend.delete(secret.id)
      Samson::Secrets::DbBackend.keys.must_equal []
    end
  end

  describe ".write" do
    it "stores the secret" do
      create_secret secret.id + 'x'
      Samson::Secrets::DbBackend.read(secret.id + 'x')[:value].must_equal 'MY-SECRET'
    end
  end

  describe Samson::Secrets::DbBackend::Secret do
    # A hack to make attr_encrypted always behave the same even when loaded without a database being present.
    # On load it checks if the column exists and then defined attr_accessors if they do not.
    # Reproduce with: `CI=1 RAILS_ENV=test rake db:drop db:create default`
    # https://github.com/attr-encrypted/attr_encrypted/issues/226
    if ENV['CI'] && Samson::Secrets::DbBackend::Secret.instance_methods.include?(:encrypted_value_iv)
      [:encrypted_value_iv, :encrypted_value_iv=, :encrypted_value, :encrypted_value=].each do |m|
        SecretStorage::DbBackend::Secret.send(:undef_method, m)
      end
    end

    describe "#value " do
      it "is encrypted" do
        secret.value.must_equal "MY-SECRET"
        secret.encrypted_value.size.must_be :>, 10 # cannot assert equality since it is always different
      end

      it "can decrypt existing" do
        SecretStorage::DbBackend::Secret.find(secret.id).value.must_equal "MY-SECRET"
      end
    end

    describe "#store_encryption_key_sha" do
      it "stores the encryption key sha so we can rotate it in the future" do
        secret.encryption_key_sha.must_equal "c975b468c4677aa69a20769bf9553ea1937b84684c2876130f9c528731963f4d"
      end
    end

    describe "validations" do
      it "is valid" do
        assert_valid secret
      end

      it "is invalid without secret" do
        secret.value = nil
        refute_valid secret
      end

      it "is invalid without id" do
        secret.id = nil
        refute_valid secret
      end

      it "is invalid without key" do
        secret.id = "a/b/c/"
        refute_valid secret
      end

      it "is valid with keys with slashes" do
        secret.id = "a/b/c/d/e/f/g"
        assert_valid secret
      end
    end
  end
end

require "spec_helper"

module Vault
  describe Logical do
    subject { vault_test_client.logical }

    before(:context) do
      next unless versioned_kv_by_default?

      vault_test_client.sys.unmount("secret")
      vault_test_client.sys.mount(
        "secret", "kv", "v1 KV", options: {version: "1"}
      )
    end

    after(:context) do
      next unless versioned_kv_by_default?

      vault_test_client.sys.unmount("secret")
      vault_test_client.sys.mount(
        "secret", "kv", "v2 KV", options: {version: "2"}
      )
    end

    describe "#list" do
      it "returns the empty array when no items exist" do
        expect(subject.list("secret/that/never/existed")).to eq([])
      end

      it "returns all secrets" do
        subject.write("secret/test-list-1", foo: "bar")
        subject.write("secret/test-list-2", foo: "bar")
        secrets = subject.list("secret")
        expect(secrets).to be_a(Array)
        expect(secrets).to include("test-list-1")
        expect(secrets).to include("test-list-2")
      end
    end

    describe "#read" do
      it "returns nil with the thing does not exist" do
        expect(subject.read("secret/foo/bar/zip")).to be(nil)
      end

      it "returns the secret when it exists" do
        subject.write("secret/test-read", foo: "bar")
        secret = subject.read("secret/test-read")
        expect(secret).to be
        expect(secret.data).to eq(foo: "bar")
      end

      it "allows special characters" do
        subject.write("secret/b:@c%n-read", foo: "bar")
        secret = subject.read("secret/b:@c%n-read")
        expect(secret).to be
        expect(secret.data).to eq(foo: "bar")
      end
    end

    describe "#write" do
      it "creates and returns the secret" do
        subject.write("secret/test-write", zip: "zap")
        result = subject.read("secret/test-write")
        expect(result).to be
        expect(result.data).to eq(zip: "zap")
      end

      it "overwrites existing secrets" do
        subject.write("secret/test-overwrite", zip: "zap")
        subject.write("secret/test-overwrite", bacon: true)
        result = subject.read("secret/test-overwrite")
        expect(result).to be
        expect(result.data).to eq(bacon: true)
      end

      it "allows special characters" do
        subject.write("secret/b:@c%n-write", foo: "bar")
        subject.write("secret/b:@c%n-write", bacon: true)
        secret = subject.read("secret/b:@c%n-write")
        expect(secret).to be
        expect(secret.data).to eq(bacon: true)
      end

      it "respects spaces properly" do
        key = 'secret/sub/"Test Group"'
        subject.write(key, foo: "bar")
        expect(subject.list("secret/sub")).to eq(['"Test Group"'])
        secret = subject.read(key)
        expect(secret).to be
        expect(secret.data).to eq(foo:"bar")
      end
    end

    describe "#delete" do
      it "deletes the secret" do
        subject.write("secret/delete", foo: "bar")
        expect(subject.delete("secret/delete")).to be(true)
        expect(subject.read("secret/delete")).to be(nil)
      end

      it "allows special characters" do
        subject.write("secret/b:@c%n-delete", foo: "bar")
        expect(subject.delete("secret/b:@c%n-delete")).to be(true)
        expect(subject.read("secret/b:@c%n-delete")).to be(nil)
      end

      it "does not error if the secret does not exist" do
        expect {
          subject.delete("secret/delete")
          subject.delete("secret/delete")
          subject.delete("secret/delete")
        }.to_not raise_error
      end
    end

    describe "#unwrap", vault: ">= 0.6" do
      it "returns the wrapped secret when it exists" do
        wrapped = vault_test_client.auth_token.create(wrap_ttl: "5s")
        unwrapped = subject.unwrap(wrapped.wrap_info.token)

        expect(unwrapped.auth).to be
        expect(unwrapped.auth.client_token).to be

        vault_test_client.with_token(unwrapped.auth.client_token) do |client|
          expect { client.logical.read("secret/test") }.to_not raise_error
        end
      end
    end

    describe "#unwrap_token", vault: ">= 0.6" do
      it "returns the wrapped token when given a string" do
        wrapped = vault_test_client.auth_token.create(wrap_ttl: "5s")
        unwrapped = subject.unwrap_token(wrapped.wrap_info.token)

        expect(unwrapped).to be

        vault_test_client.with_token(unwrapped) do |client|
          expect { client.logical.read("secret/test") }.to_not raise_error
        end
      end

      it "returns the wrapped token when given a Vault::Secret" do
        wrapped = vault_test_client.auth_token.create(wrap_ttl: "5s")
        unwrapped = subject.unwrap_token(wrapped)

        expect(unwrapped).to be

        vault_test_client.with_token(unwrapped) do |client|
          expect { client.logical.read("secret/test") }.to_not raise_error
        end
      end

      it "returns nil when the response is empty" do
        token = vault_test_client.auth_token.create # Note no wrap-ttl here
        unwrapped = subject.unwrap_token(token.auth.client_token)
        expect(unwrapped).to be(nil)
      end
    end
  end
end

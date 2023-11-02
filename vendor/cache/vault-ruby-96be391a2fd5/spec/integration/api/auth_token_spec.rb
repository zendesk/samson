require "spec_helper"

module Vault
  describe AuthToken, vault: ">= 0.6.1" do
    subject { vault_test_client }

    describe "#accessors" do
      it "lists all accessors" do
        result = subject.auth_token.accessors
        expect(result).to be_a(Vault::Secret)
      end
    end

    describe "#create" do
      it "creates a new token" do
        result = subject.auth_token.create
        expect(result).to be_a(Vault::Secret)
        expect(result.auth).to be_a(Vault::SecretAuth)
        expect(result.auth.client_token).to be
      end

      it "creates a new token as a wrapped response" do
        ttl = 50
        result = subject.auth_token.create(wrap_ttl: ttl)
        expect(result).to be_a(Vault::Secret)
        expect(result.wrap_info).to be_a(Vault::WrapInfo)
        expect(result.wrap_info.ttl).to eq(ttl)
        expect(result.wrap_info.token).to be
      end
    end

    describe "#create_orphan" do
      it "creates an orphaned token" do
        result = subject.auth_token.create_orphan
        expect(result).to be_a(Vault::Secret)
        expect(result.auth).to be_a(Vault::SecretAuth)
        expect(result.auth.client_token).to be
      end

      it "creates an orphaned token as a wrapped response" do
        ttl = 50
        result = subject.auth_token.create_orphan(wrap_ttl: ttl)
        expect(result).to be_a(Vault::Secret)
        expect(result.wrap_info).to be_a(Vault::WrapInfo)
        expect(result.wrap_info.ttl).to eq(ttl)
        expect(result.wrap_info.token).to be
      end
    end

    describe "#create_with_role" do
      it "creates a token attached to a role" do
        vault_test_client.logical.write("auth/token/roles/default")
        result = subject.auth_token.create_with_role("default")
        expect(result).to be_a(Vault::Secret)
        expect(result.auth).to be_a(Vault::SecretAuth)
        expect(result.auth.client_token).to be
      end

      it "creates a new token attached to a role as a wrapped response" do
        ttl = 50
        vault_test_client.logical.write("auth/token/roles/default")
        result = subject.auth_token.create_with_role("default", wrap_ttl: ttl)
        expect(result).to be_a(Vault::Secret)
        expect(result.wrap_info).to be_a(Vault::WrapInfo)
        expect(result.wrap_info.ttl).to eq(ttl)
        expect(result.wrap_info.token).to be
      end
    end

    describe "#lookup" do
      it "retrieves the given token" do
        result = subject.auth_token.lookup(subject.token)
        expect(result).to be_a(Vault::Secret)
        expect(result.data[:id]).to eq(subject.token)
      end
    end

    describe "#lookup_accessor" do
      it "retrieves accessor information" do
        accessor = subject.auth_token.create.auth.accessor
        result = subject.auth_token.lookup_accessor(accessor)
        expect(result).to be_a(Vault::Secret)
        expect(result.data[:accessor]).to eq(accessor)
      end
    end

    describe "#lookup_self" do
      it "retrieves the current token" do
        result = subject.auth_token.lookup_self
        expect(result).to be_a(Vault::Secret)
        expect(result.data[:id]).to eq(subject.token)
      end
    end

    describe "#renew_self" do
      it "renews the calling token" do
        token = subject.auth_token.create(policies: ["default"])
        subject.auth.token(token.auth.client_token)
        result = subject.auth_token.renew_self
        expect(result).to be_a(Vault::Secret)
        expect(result.auth).to be_a(Vault::SecretAuth)
      end
    end

    describe "#revoke_self" do
      it "revokes the calling token" do
        token = subject.auth_token.create(policies: ["default"])
        subject.auth.token(token.auth.client_token)
        result = subject.auth_token.revoke_self
        expect(result).to be(nil)
      end
    end

    describe "#renew" do
      it "renews the auth"

      it "returns an error if the auth is not renewable"
    end

    describe "#revoke_orphan" do
      it "revokes the token, but not children" do
        token = subject.auth_token.create.auth.client_token

        child = subject.with_token(token) do |c|
          c.auth_token.create.auth.client_token
        end

        result = subject.auth_token.revoke_orphan(token)
        expect(result).to be(true)

        result = subject.auth_token.lookup(child)
        expect(result).to be_a(Vault::Secret)
      end
    end

    describe "#revoke_accessor" do
      it "revokes the accessor"
    end

    describe "#revoke" do
      it "revokes a token" do
        token = subject.auth_token.create.auth.client_token

        result = subject.auth_token.revoke(token)
        expect(result).to be(true)

        expect {
          subject.auth_token.lookup(token)
        }.to raise_error { |e|
          expect(e.code).to eq(403)
        }
      end

      it "revokes the tree" do
        original_token = subject.token

        parent = subject.auth_token.create.auth.client_token

        subject.auth.token(parent)
        child = subject.auth_token.create.auth.client_token
        subject.auth.token(original_token)

        result = subject.auth_token.revoke(parent)
        expect(result).to be(true)

        expect {
          subject.auth_token.lookup(child)
        }.to raise_error { |e|
          expect(e.code).to eq(403)
        }
      end
    end
  end
end

require "spec_helper"

module Vault
  describe AppRole, vault: ">= 0.6.1" do
    subject { vault_test_client.approle }

    before(:context) do
      vault_test_client.sys.enable_auth("approle", "approle", nil)
      @approle  = "sample-role-name"
    end

    after(:context) do
      vault_test_client.sys.disable_auth("approle")
    end

    let(:role) do
      {
        bind_secret_id:     true,
        bound_cidr_list:    "",
        secret_id_num_uses: 10,
        secret_id_ttl:      3600,
        policies:           "default",
        period:             1800
      }
    end

    before do
      vault_test_client.approle.set_role(@approle)
    end

    after do
      vault_test_client.approle.delete_role(@approle)
    end

    describe "#set_role" do
      it "sets the AppRole" do
        expect(subject.set_role(@approle, role)).to be(true)
      end
    end

    describe "#role" do
      it "reads the AppRole" do
        subject.set_role(@approle, role)
        result = subject.role(@approle)
        expect(result).to be_a(Vault::Secret)
        expect(result.data[:policies]).to eq(["default"])
        expect(result.data[:period]).to eq(1800)
        expect(result.data[:secret_id_ttl]).to eq(3600)
        expect(result.data[:secret_id_num_uses]).to eq(10)
      end

      it "returns nil when the AppRole does not exist" do
        result = subject.role("nope-nope-nope")
        expect(result).to be(nil)
      end
    end

    describe "#roles" do
      it "lists all AppRoles by name" do
        result = subject.roles
        expect(result).to include(@approle)
      end
    end

    describe "#role_id" do
      it "reads the AppRole ID" do
        result = subject.role_id(@approle)
        expect(result).to be_a(String)
      end

      it "returns nil when the AppRole does not exist" do
        result = subject.role_id("nope-nope-nope")
        expect(result).to be(nil)
      end
    end

    describe "#set_role_id" do
      it "sets the AppRole ID" do
        expect(subject.set_role_id(@approle, "testroleid")).to be(true)
        expect(subject.role_id(@approle)).to eq("testroleid")
      end
    end

    describe "#delete_role", vault: ">= 0.6.2" do
      it "deletes the AppRole" do
        expect(subject.delete_role(@approle)).to be(true)
      end

      it "does nothing if the AppRole does not exist" do
        expect {
          subject.delete_role("nope-nope-nope")
        }.to_not raise_error
      end
    end

    describe "#create_secret_id" do
      it "generates the new SecretID" do
        result = subject.create_secret_id(@approle)
        expect(result).to be_a(Vault::Secret)
        expect(result.data).to include(:secret_id)
        expect(result.data).to include(:secret_id_accessor)
        expect(result.data[:secret_id]).to be_a(String)
        expect(result.data[:secret_id_accessor]).to be_a(String)
      end

      it "assigns the custom SecretID" do
        opts = { secret_id: "testsecretid" }
        result = subject.create_secret_id(@approle, opts)
        expect(result).to be_a(Vault::Secret)
        expect(result.data).to include(secret_id: "testsecretid")
        expect(result.data).to include(:secret_id_accessor)
        expect(result.data[:secret_id_accessor]).to be_a(String)
      end
    end

    describe "#secret_id" do
      it "reads the SecretID" do
        opts = { secret_id: "testsecretid" }
        subject.create_secret_id(@approle, opts)
        result = subject.secret_id(@approle, "testsecretid")
        expect(result).to be_a(Vault::Secret)
        expect(result.data).to include(:secret_id_accessor)
        expect(result.data).to include(:secret_id_num_uses)
        expect(result.data).to include(:secret_id_ttl)
      end

      it "returns nil when the SecretId does not exist" do
        result = subject.secret_id(@approle, "nope-nope-nope")
        expect(result).to be(nil)
      end
    end

    describe "#secret_id_accessors" do
      it "lists all SecretID accessors" do
        2.times { subject.create_secret_id(@approle) }
        result = subject.secret_id_accessors(@approle)
        expect(result).to be_an(Array)
        expect(result.length).to eq(2)
      end
    end
  end
end

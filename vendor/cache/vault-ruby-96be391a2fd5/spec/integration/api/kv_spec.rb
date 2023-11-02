require "spec_helper"

module Vault
  describe KV, vault: ">= 0.10" do
    subject { vault_test_client.kv("versioned-kv") }

    before(:context) do
      vault_test_client.sys.mount(
        "versioned-kv", "kv", "v2 KV", options: {version: "2"}
      )
    end

    after(:context) do
      vault_test_client.sys.unmount("versioned-kv")
    end

    describe "#list" do
      it "returns the empty array when no items exist" do
        expect(subject.list("secrets/that/never/existed")).to eq([])
      end

      it "returns all secrets" do
        subject.write("secrets/test-list-1", foo: "bar")
        subject.write("secrets/test-list-2", foo: "bar")
        secrets = subject.list("secrets")

        expect(secrets).to be_a(Array)
        expect(secrets).to include("test-list-1")
        expect(secrets).to include("test-list-2")
      end
    end

    describe "#read" do
      it "returns nil with the thing does not exist" do
        expect(subject.read("foo/bar/zip")).to be(nil)
      end

      it "returns the secret when it exists" do
        subject.write("test-read", foo: "bar")
        secret = subject.read("test-read")
        expect(secret).to be
        expect(secret.data).to eq(foo: "bar")
      end

      it "allows special characters" do
        subject.write("b:@c%n-read", foo: "bar")
        secret = subject.read("b:@c%n-read")
        expect(secret).to be
        expect(secret.data).to eq(foo: "bar")
      end

      it "allows reading of old versions" do
        subject.write("test", foo: "bar")
        subject.write("test", foo: "baz")
        secret = subject.read("test", 1)
        expect(secret.data).to eq(foo: "bar")
      end

      it "returns the secret metadata" do
        subject.write("b:@c%n-read", foo: "bar")
        secret = subject.read("b:@c%n-read")
        expect(secret).to be
        expect(secret.metadata.keys).to match_array([:created_time, :deletion_time, :version, :destroyed])
      end
    end

    describe "#read_metadata" do
      it "returns nil if the thing does not exist" do
        expect(subject.read_metadata("foo/bar/zip")).to be(nil)
      end

      it "returns the metadata when it exists" do
        subject.write("test-read", foo: "bar")
        expect(subject.read_metadata("test-read")).to be_a(Hash)
      end
    end

    describe "#write" do
      it "creates and returns the secret" do
        subject.write("test-write", zip: "zap")
        result = subject.read("test-write")
        expect(result).to be
        expect(result.data).to eq(zip: "zap")
      end

      it "overwrites existing secrets" do
        subject.write("test-overwrite", zip: "zap")
        subject.write("test-overwrite", bacon: true)
        result = subject.read("test-overwrite")
        expect(result).to be
        expect(result.data).to eq(bacon: true)
      end

      it "allows special characters" do
        subject.write("b:@c%n-write", foo: "bar")
        subject.write("b:@c%n-write", bacon: true)
        secret = subject.read("b:@c%n-write")
        expect(secret).to be
        expect(secret.data).to eq(bacon: true)
      end

      it "respects spaces properly" do
        key = 'sub/"Test Group"'
        subject.write(key, foo: "bar")
        expect(subject.list("sub")).to eq(['"Test Group"'])
        secret = subject.read(key)
        expect(secret).to be
        expect(secret.data).to eq(foo:"bar")
      end
    end

    describe "#write_metadata" do
      it "updates metadata for the secret" do
        subject.write("test-meta", zip: "zap")
        expect(subject.read_metadata("test-meta")[:max_versions]).to eq(0)
        subject.write_metadata("test-meta", max_versions: 3)
        expect(subject.read_metadata("test-meta")[:max_versions]).to eq(3)
      end
    end

    describe "#delete" do
      it "deletes the secret" do
        subject.write("delete", foo: "bar")
        expect(subject.delete("delete")).to be(true)
        expect(subject.read("delete")).to be(nil)
      end

      it "allows special characters" do
        subject.write("b:@c%n-delete", foo: "bar")
        expect(subject.delete("b:@c%n-delete")).to be(true)
        expect(subject.read("b:@c%n-delete")).to be(nil)
      end

      it "does not error if the secret does not exist" do
        expect {
          subject.delete("delete")
          subject.delete("delete")
          subject.delete("delete")
        }.to_not raise_error
      end
    end

    describe "#delete_versions" do
      it "can remove specific versions" do
        subject.write("delete-old", foo: "bar")
        subject.write("delete-old", foo: "baz")
        subject.delete_versions("delete-old", [1])
        expect(subject.read("delete-old", 1)).to be_nil
      end

      it "still has the versions in the history" do
        subject.write("delete-older", foo: "bar")
        subject.write("delete-older", foo: "baz")
        subject.delete_versions("delete-older", [1])
        expect(subject.read_metadata("delete-older")[:versions][:"1"]).to be
      end
    end

    describe "#undelete_versions" do
      it "restores a secret" do
        subject.write("mistake", foo: "bar")
        subject.delete("mistake")
        expect(subject.read("mistake")).to be(nil)
        subject.undelete_versions("mistake", [1])
        expect(subject.read("mistake").data).to eq(foo: "bar")
      end
    end

    describe "#destroy" do
      it "removes everything" do
        subject.write("destroy", foo: "bar")
        subject.write("destroy", foo: "baz")
        subject.destroy("destroy")
        expect(subject.read("destroy")).to be_nil
        expect(subject.read_metadata("destroy")).to be_nil
      end
    end

    describe "#destroy_versions" do
      it "can remove specific versions" do
        subject.write("destroy-old", foo: "bar")
        subject.write("destroy-old", foo: "baz")
        subject.destroy_versions("delete-old", [1])
        expect(subject.read("delete-old", 1)).to be_nil
      end

      it "ensures versions can't be restored" do
        subject.write("destroy-older", foo: "bar")
        subject.write("destroy-older", foo: "baz")
        subject.destroy_versions("destroy-older", [1])
        subject.undelete_versions("destroy-older", [1])
        expect(subject.read("destroy-older", 1)).to be_nil
      end
    end
  end
end

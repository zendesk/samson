# frozen_string_literal: true
require_relative '../../../test_helper'

SingleCov.covered! uncovered: 1

describe Samson::Secrets::DbBackend do
  let(:secret) { create_secret 'production/foo/pod2/hello' }

  describe ".read" do
    it "reads" do
      Samson::Secrets::DbBackend.read(secret.id).except(:updated_at, :created_at).must_equal(
        value: 'MY-SECRET',
        visible: false,
        comment: 'this is secret',
        updater_id: users(:admin).id,
        creator_id: users(:admin).id,
        deprecated_at: nil
      )
    end

    it "reads deprecated as string to return the same format as other backends" do
      secret.update_column(:deprecated_at, Time.at(1234567890))
      Samson::Secrets::DbBackend.read(secret.id)[:deprecated_at].must_equal "2009-02-13 23:31:30"
    end

    it "returns nil when it cannot find" do
      Samson::Secrets::DbBackend.read('production/foo/pod2/noooo').must_be_nil
    end
  end

  describe ".history" do
    it "works" do
      Samson::Secrets::DbBackend.history(secret.id).class.must_equal Hash
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

  describe ".write" do
    it "creates a new secret" do
      Samson::Secrets::DbBackend.write(
        "a/b/c/foo", comment: "fooo", value: "bar", visible: "baz", user_id: "bars", deprecated_at: nil
      ).must_equal true
    end

    it "updates an existing secret" do
      Samson::Secrets::DbBackend.write(
        secret.id, comment: "fooo", value: "bar", visible: "baz", user_id: "bars", deprecated_at: nil
      ).must_equal true
    end
  end

  describe ".ids" do
    it "returns all ids" do
      secret # trigger create
      Samson::Secrets::DbBackend.ids.must_equal [secret.id]
    end
  end

  describe ".delete" do
    it "deletes" do
      Samson::Secrets::DbBackend.delete(secret.id)
      Samson::Secrets::DbBackend.ids.must_equal []
    end
  end

  describe ".write" do
    it "stores the secret" do
      create_secret "#{secret.id}x"
      Samson::Secrets::DbBackend.read("#{secret.id}x")[:value].must_equal 'MY-SECRET'
    end
  end

  describe ".deploy_groups" do
    it "is all" do
      Samson::Secrets::DbBackend.deploy_groups.size.must_equal DeployGroup.count
    end
  end

  describe Samson::Secrets::DbBackend::Secret do
    describe "#value " do
      it "is encrypted" do
        secret.value.must_equal "MY-SECRET"
        secret.encrypted_value.size.must_be :>, 10 # cannot assert equality since it is always different
      end

      it "can decrypt existing" do
        Samson::Secrets::DbBackend::Secret.find(secret.id).value.must_equal "MY-SECRET"
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

      it "is invalid without id" do
        secret.id = "a/b/c/"
        refute_valid secret
      end

      it "is valid with ids with slashes" do
        secret.id = "a/b/c/d/e/f/g"
        assert_valid secret
      end
    end
  end
end

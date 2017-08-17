# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Changeset::GithubUser do
  let(:user) do
    Changeset::GithubUser.new(
      stub(
        "data",
        avatar_url: "https://avatars.githubusercontent.com/u/1337?v=2",
        login: 'foo'
      )
    )
  end
  # comitter with email unknown to github
  let(:unknown_user) { Changeset::GithubUser.new(stub("data", login: nil, avatar_url: nil)) }

  describe "#avatar_url" do
    it "returns the URL for the user's avatar" do
      user.avatar_url.must_equal "https://avatars.githubusercontent.com/u/1337?v=2&s=20"
    end

    it "returns default avatar when user is unknown" do
      unknown_user.avatar_url.must_equal "https://assets-cdn.github.com/images/gravatars/gravatar-user-420.png"
    end
  end

  describe "#url" do
    it "returns an url" do
      user.url.must_equal "https://github.com/foo"
    end

    it "returns nil when user is unknown" do
      unknown_user.url.must_be_nil
    end
  end

  describe "#login" do
    it "returns login" do
      user.login.must_equal "foo"
    end
  end

  describe "#identifier" do
    it "returns an identifier" do
      user.identifier.must_equal "@foo"
    end

    it "returns nil an identifier" do
      unknown_user.identifier.must_equal nil
    end
  end

  describe "#eql?" do
    it "is equal if the login matches" do
      other = Changeset::GithubUser.new(stub("data", login: "foo"))
      user.eql?(other).must_equal true
    end

    it "is not equal if the login does not match" do
      other = Changeset::GithubUser.new(stub("data", login: "bar "))
      user.eql?(other).must_equal false
    end

    it "is equal if both users are unknown" do
      other = Changeset::GithubUser.new(stub("data", login: nil))
      unknown_user.eql?(other).must_equal true
    end

    it "is equal for same unknown user" do
      unknown_user.eql?(unknown_user).must_equal true
    end
  end

  describe "#hash" do
    it "returns the hash of a login" do
      user.hash.must_equal "foo".hash
    end

    it "returns static id for unknown" do
      unknown_user.hash.must_equal 123456789
    end
  end
end

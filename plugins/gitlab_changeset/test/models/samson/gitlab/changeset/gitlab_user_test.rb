# frozen_string_literal: true
require_relative '../../../../test_helper'

SingleCov.covered!

describe Samson::Gitlab::Changeset::GitlabUser do

  let (:user_email) {'email@plansource.com'}

  describe "unknown user" do
    before :each do
      mock_client = Minitest::Mock.new
      mock_client.expect(:users, [], [{search: user_email}])
      Gitlab::Client.stubs(:new).returns(mock_client)
    end

    # comitter with email unknown to github
    let(:unknown_user) { Samson::Gitlab::Changeset::GitlabUser.new(user_email) }

    describe "#avatar_url" do
      it "returns default avatar when user is unknown" do
        unknown_user.avatar_url.must_equal "https://gitlab.com/assets/no_avatar-849f9c04a3a0d0cea2424ae97b27447dc64a7dbfae83c036c45b403392f0e8ba.png"
      end
    end

    describe "#url" do
      it "returns nil when user is unknown" do
        unknown_user.url.must_be_nil
      end
    end

    describe "#identifier" do
      it "returns nil an identifier" do
        unknown_user.identifier.must_equal nil
      end
    end

    describe "#eql?" do
      it "is equal if both users are unknown" do        mock_client = Minitest::Mock.new
      mock_client.expect(:users, [], [{search: user_email}])
      mock_client.expect(:users, [], [{search: user_email}])
      Gitlab::Client.stubs(:new).returns(mock_client)

      other = Samson::Gitlab::Changeset::GitlabUser.new(user_email)
        unknown_user.eql?(other).must_equal true
      end

      it "is equal for same unknown user" do
        unknown_user.eql?(unknown_user).must_equal true
      end
    end

    describe "#hash" do
      it "returns static id for unknown" do
        unknown_user.hash.must_equal 123456789
      end
    end
  end

  describe 'known user' do
    before :each do
      mock_client = Minitest::Mock.new
      mock_client.expect(:users, [OpenStruct.new({avatar_url: "https://avatars.githubusercontent.com/u/1337?v=2", web_url: 'https://git.plansource.com/mickey'})], [{search: user_email}])
      Gitlab::Client.stubs(:new).returns(mock_client)
    end

    let(:user) do
      Samson::Gitlab::Changeset::GitlabUser.new(user_email)
    end

    describe "#avatar_url" do
      it "returns the URL for the user's avatar" do
        user.avatar_url.must_equal "https://avatars.githubusercontent.com/u/1337?v=2&s=20"
      end
    end

    describe "#url" do
      it "returns an url" do
        user.url.must_equal "https://git.plansource.com/mickey"
      end
    end

    describe "#login" do
      it "returns login" do
        user.login.must_equal "mickey"
      end
    end

    describe "#identifier" do
      it "returns an identifier" do
        user.identifier.must_equal "@mickey"
      end
    end

    describe "#eql?" do
      it "is equal if the login matches" do
        mock_client = Minitest::Mock.new
        mock_client.expect(:users, [OpenStruct.new({avatar_url: "https://avatars.githubusercontent.com/u/1337?v=2", web_url: 'https://git.plansource.com/mickey'})], [{search: user_email}])
        mock_client.expect(:users, [OpenStruct.new({avatar_url: "https://avatars.githubusercontent.com/u/1337?v=2", web_url: 'https://git.plansource.com/mickey'})], [{search: user_email}])
        Gitlab::Client.stubs(:new).returns(mock_client)

        other = Samson::Gitlab::Changeset::GitlabUser.new(user_email)
        user.eql?(other).must_equal true
      end

      it "is not equal if the login does not match" do
        mock_client = Minitest::Mock.new
        mock_client.expect(:users, [OpenStruct.new({avatar_url: "https://avatars.githubusercontent.com/u/1337?v=2", web_url: 'https://git.plansource.com/mickey'})], [{search: user_email}])
        mock_client.expect(:users, [OpenStruct.new({avatar_url: "https://avatars.githubusercontent.com/u/1337?v=2", web_url: 'https://git.plansource.com/goofy'})], [{search: user_email}])
        Gitlab::Client.stubs(:new).returns(mock_client)
        other = Samson::Gitlab::Changeset::GitlabUser.new(user_email)
        user.eql?(other).must_equal false
      end
    end

    describe "#hash" do
      it "returns the hash of a login" do
        user.hash.must_equal "mickey".hash
      end
    end
  end

  describe 'error getting user' do
    it 'returns empty user on error' do
      mock_client = Minitest::Mock.new
      mock_client.expect(:users, nil, [{search: user_email}])
      Gitlab::Client.stubs(:new).returns(mock_client)

      user = Samson::Gitlab::Changeset::GitlabUser.new(user_email)
      user.url.must_equal nil
      user.avatar_url.must_equal 'https://gitlab.com/assets/no_avatar-849f9c04a3a0d0cea2424ae97b27447dc64a7dbfae83c036c45b403392f0e8ba.png'
    end
  end
end

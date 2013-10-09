require 'test_helper'

describe User do
  describe ".find_or_create_from_oauth" do
    let(:user) { User.find_or_create_from_oauth(auth, strategy) }
    let(:client) { OAuth2::Client.new("test", "secret") }
    let(:token) { OAuth2::AccessToken.new(client, "abc123") }
    let(:auth) { Hashie::Mash.new(:info => info) }

    let(:strategy) do
      mock = Minitest::Mock.new
      mock.expect(:access_token, token)
      mock.expect(:client, client)
      mock
    end

    describe "with an end-user hash" do
      let(:info) {{ :role => "end-user" }}

      it "wont create a user" do
        user.must_be_nil
      end
    end

    describe "with an anonymous user hash" do
      let(:info) {{}}

      it "wont create a user" do
        user.must_be_nil
      end
    end

    describe "with a new user" do
      let(:info) {{
        :name => "Test User",
        :email => "test@example.org",
        :role => "admin"
      }}

      before do
        stub_request(:get, %r{/api/v2/oauth/tokens/current}).to_return(
          :headers => { :content_type => "application/json" },
          :body => JSON.dump(:token => { :id => 1 })
        )

        stub_request(:delete, %r{/api/v2/oauth/tokens/1})
      end

      it "creates a new user" do
        user.persisted?.must_equal(true)
      end

      it "sets the current token" do
        user.current_token.must_equal("abc123")
      end
    end

    describe "with an existing user" do
      let(:info) {{
        :name => "Test User",
        :email => "test@example.org",
      }}

      let(:existing_user) do
        User.create!(:name => "Test", :email => "test@example.org")
      end

      before do
        stub_request(:get, %r{/api/v2/oauth/tokens/current}).
          with(:headers => { :authorization => "Bearer abc123" }).
          to_return(
            :headers => { :content_type => "application/json" },
            :body => JSON.dump(:token => { :id => 1 })
          )

        stub_request(:delete, %r{/api/v2/oauth/tokens/1})

        existing_user
      end

      it "updates the user" do
        user.name.must_equal("Test User")
      end

      it "is the same user" do
        existing_user.id.must_equal(user.id)
      end

      it "sets the current token" do
        user.current_token.must_equal("abc123")
      end

      describe "with a current_token" do
        before do
          existing_user.update_attributes!(:current_token => "def456")
        end

        it "resets the current token" do
          user.current_token.must_equal("abc123")
        end
      end
    end
  end

  describe "#admin?" do
    it "is true for an admin" do
      users(:admin).is_admin?.must_equal(true)
    end

    it "is false for a deployer" do
      users(:deployer).is_admin?.wont_equal(true)
    end

    it "is false for an viewer" do
      User.new.is_admin?.wont_equal(true)
    end
  end

  describe "#deployer?" do
    it "is true for an admin" do
      users(:admin).is_deployer?.must_equal(true)
    end

    it "is true for a deployer" do
      users(:deployer).is_deployer?.must_equal(true)
    end

    it "is false for an viewer" do
      User.new.is_deployer?.wont_equal(true)
    end
  end

  describe "#viewer?" do
    it "is true for a deployer" do
      users(:deployer).is_deployer?.must_equal(true)
    end

    it "is true for everyone else and by default" do
      User.new.is_viewer?.must_equal(true)
    end
  end
end

require_relative '../test_helper'

describe User do
  describe ".create_or_update_from_hash" do
    let(:user) { User.create_or_update_from_hash(hash) }

    describe "with a new user" do
      let(:hash) {{
        :name => "Test User",
        :email => "test@example.org",
        :role_id => Role::ADMIN.id,
        :current_token => "abc123"
      }}

      it "creates a new user" do
        user.persisted?.must_equal(true)
      end

      it "sets the current token" do
        user.current_token.must_equal("abc123")
      end

      it "sets the role_id" do
        user.role_id.must_equal(Role::ADMIN.id)
      end
    end

    describe "with an existing user" do
      let(:hash) {{
        :name => "Test User",
        :email => "test@example.org",
        :current_token => "abc123"
      }}

      let(:existing_user) do
        User.create!(:name => "Test", :email => "test@example.org")
      end

      setup { existing_user }

      it "updates the user" do
        user.name.must_equal("Test User")
      end

      it "is the same user" do
        existing_user.id.must_equal(user.id)
      end

      it "sets the current token" do
        user.current_token.must_equal("abc123")
      end

      describe "with a higher role_id" do
        let(:hash) {{
          :name => "Test User",
          :email => "test@example.org",
          :role_id => Role::ADMIN.id
        }}

        setup do
          existing_user.update_attributes!(:role_id => Role::VIEWER.id)
        end

        it "is overwritten" do
          user.role_id.must_equal(Role::ADMIN.id)
        end
      end

      describe "with a lower role_id" do
        let(:hash) {{
          :name => "Test User",
          :email => "test@example.org",
          :role_id => Role::VIEWER.id
        }}

        setup do
          existing_user.update_attributes!(role_id: Role::ADMIN.id)
        end

        it "is ignored" do
          user.role_id.must_equal(Role::ADMIN.id)
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

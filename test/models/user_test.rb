require_relative '../test_helper'

describe User do
  describe "#name" do
    let(:user) { User.new(name: username, email: 'test@test.com') }

    describe 'nil name' do
      let(:username) { nil }
      it 'falls back to the email' do
        user.name.must_equal('test@test.com')
      end
    end

    describe 'blank name' do
      let(:username) { '' }
      it 'falls back to the email' do
        user.name.must_equal('test@test.com')
      end
    end

    describe 'real name' do
      let(:username) { 'Hello' }
      it 'uses the name' do
        user.name.must_equal(username)
      end
    end
  end

  describe "#gravatar url" do
    let(:user) { User.new(name: "User Name", email: email) }

    describe 'real email' do
      let(:email) { 'test@test.com' }
      it 'returns proper gravatar url' do
        email_digest = Digest::MD5.hexdigest('test@test.com')
        user.gravatar_url.must_equal("https://www.gravatar.com/avatar/#{email_digest}")
      end
    end

    describe 'nil email' do
      let(:email) { nil }
      it 'falls back to the default gravatar' do
        user.gravatar_url.must_equal('https://www.gravatar.com/avatar/default')
      end
    end

    describe 'empty email' do
      let(:email) { "" }
      it 'falls back to the default gravatar' do
        user.gravatar_url.must_equal('https://www.gravatar.com/avatar/default')
      end
    end
  end

  describe ".create_or_update_from_hash" do
    let(:user) { User.create_or_update_from_hash(auth_hash) }

    describe "with a new user" do
      let(:auth_hash) {{
        name: "Test User",
        email: "test@example.org",
        role_id: Role::ADMIN.id,
        external_id: 'strange-bug',
      }}

      it "creates a new user" do
        user.persisted?.must_equal(true)
      end

      it "sets the token" do
        user.token.must_match(/[a-z0-9]+/)
      end

      it "sets the role_id" do
        user.role_id.must_equal(Role::ADMIN.id)
      end
    end

    describe "with an existing user" do
      let(:auth_hash) {{
        name: "Test User",
        email: "test@example.org",
        external_id: 9,
        token: "abc123",
      }}

      let(:existing_user) do
        User.create!(name: "Test", external_id: 9)
      end

      setup { existing_user }

      it "does not update the user" do
        user.name.must_equal("Test")
        user.token.wont_equal("abc123")
      end

      it "does update nil fields" do
        user.email.must_equal("test@example.org")
      end

      it "is the same user" do
        existing_user.id.must_equal(user.id)
      end

      describe "with a higher role_id" do
        let(:auth_hash) {{
          name: "Test User",
          email: "test@example.org",
          external_id: 9,
          role_id: Role::ADMIN.id
        }}

        setup do
          existing_user.update_attributes!(role_id: Role::VIEWER.id)
        end

        it "is overwritten" do
          user.role_id.must_equal(Role::ADMIN.id)
        end
      end

      describe "with a lower role_id" do
        let(:auth_hash) {{
          name: "Test User",
          email: "test@example.org",
          external_id: 9,
          role_id: Role::VIEWER.id
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

  describe "#super_admin?" do
    it "is true for a super admin" do
      users(:super_admin).must_be(:is_super_admin?)
    end

    it "is false for an admin" do
      users(:admin).wont_be(:is_super_admin?)
    end

    it "is false for deployer" do
      users(:deployer).wont_be(:is_super_admin?)
    end

    it "is false for a viewer" do
      User.new.wont_be(:is_super_admin?)
    end
  end

  describe "#deployer?" do
    it "is true for a super_admin" do
      users(:super_admin).is_deployer?.must_equal(true)
    end

    it "is true for an admin" do
      users(:admin).is_admin?.must_equal(true)
    end

    it "is false for a viewer" do
      User.new.wont_be(:is_deployer?)
    end
  end

  describe "#viewer?" do
    it "is true for a super_admin" do
      users(:super_admin).is_viewer?.must_equal(true)
    end

    it "is true for an admin" do
      users(:admin).is_viewer?.must_equal(true)
    end

    it "is true for a deployer" do
      users(:deployer).is_viewer?.must_equal(true)
    end

    it "is true for everyone else and by default" do
      User.new.is_viewer?.must_equal(true)
    end
  end

  describe "search_for scope" do

    let!(:a_singular_user) do
      User.create!(name: 'FindMe', email: 'find.me@example.org')
    end

    let!(:some_similar_users) do
      (1..3).map { |index| User.create!(name: "TestUser#{index}", email: "some_email#{index}@example.org") }
    end

    it 'finds a single user' do
      User.search('FindMe').must_equal [a_singular_user]
    end

    it 'finds a single user using the email as query' do
      User.search('find.me@example.org').must_equal [a_singular_user]
    end

    it 'finds a single user using a partial match query' do
      User.search('find').must_equal [a_singular_user]
    end

    it 'finds multiple results using a partial match query' do
      User.search('TestUser').count.must_equal(3)
    end

    it 'fails to find any result' do
      User.search('does not exist').count.must_equal(0)
    end

    it 'must return all results with an empty query' do
      User.search('').count.must_equal(User.count)
    end

    it 'must return all results with a nil query' do
      User.search(nil).count.must_equal(User.count)
    end

  end

  describe 'soft delete!' do
    let(:user) { User.create!(name: 'to_delete', email: 'to_delete@test.com') }
    let!(:locks) do
      %i(test_staging test_production).map { |stage| user.locks.create!(stage: stages(stage)) }
    end

    it 'soft deletes all the user locks when the user is soft deleted' do
      user.soft_delete!
      locks.each { |lock| lock.reload.deleted_at.wont_be_nil }
    end
  end
end

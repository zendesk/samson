# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

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

  describe "#time_format" do
    let(:user) { User.create!(name: "jimbob", email: 'test@test.com') }
    it "has a default time format of relative" do
      user.time_format.must_equal('relative')
    end

    it "does not update with invalid values" do
      user.time_format = 'foobar'
      refute user.valid?
    end

    it "does update with valid values" do
      user.update_attributes!(time_format: 'utc')
      user.reload
      user.time_format.must_equal('utc')
    end

    it "allows initialization with different time_format" do
      local_user = User.create!(name: "bettysue", email: 'bsue@test.com', time_format: 'local')
      local_user.time_format.must_equal('local')
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
      let(:auth_hash) do
        {
          name: "Test User",
          email: "test@example.org",
          role_id: Role::ADMIN.id,
          external_id: 'strange-bug'
        }
      end

      it "creates a new user" do
        user.persisted?.must_equal(true)
      end

      it "sets the token" do
        user.token.must_match(/[a-z0-9]+/)
      end

      it "sets the role_id" do
        user.role_id.must_equal(Role::ADMIN.id)
      end

      it "creates a super admin for the first user" do
        User.delete_all
        user.role_id.must_equal(Role::SUPER_ADMIN.id)
      end
    end

    describe "with an existing user" do
      let(:auth_hash) do
        {
          name: "Test User",
          email: "test@example.org",
          external_id: 9,
          token: "abc123"
        }
      end

      let(:existing_user) do
        User.create!(name: "Test", external_id: 9)
      end

      before { existing_user }

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
        let(:auth_hash) do
          {
            name: "Test User",
            email: "test@example.org",
            external_id: 9,
            role_id: Role::ADMIN.id
          }
        end

        before do
          existing_user.update_attributes!(role_id: Role::VIEWER.id)
        end

        it "is overwritten" do
          user.role_id.must_equal(Role::ADMIN.id)
        end
      end

      describe "with a lower role_id" do
        let(:auth_hash) do
          {
            name: "Test User",
            email: "test@example.org",
            external_id: 9,
            role_id: Role::VIEWER.id
          }
        end

        before do
          existing_user.update_attributes!(role_id: Role::ADMIN.id)
        end

        it "is ignored" do
          user.role_id.must_equal(Role::ADMIN.id)
        end
      end
    end
  end

  describe ".administrated_projects" do
    it "is all for admin" do
      users(:admin).administrated_projects.map(&:id).sort.must_equal Project.pluck(:id).sort
    end

    it "is allowed for project admin" do
      users(:project_admin).administrated_projects.map(&:permalink).sort.must_equal ['foo']
    end
  end

  describe "#super_admin?" do
    it "is true for a super admin" do
      users(:super_admin).must_be(:super_admin?)
    end

    it "is false for an admin" do
      users(:admin).wont_be(:super_admin?)
    end

    it "is false for deployer" do
      users(:deployer).wont_be(:super_admin?)
    end

    it "is false for a viewer" do
      User.new.wont_be(:super_admin?)
    end
  end

  describe "#deployer?" do
    it "is true for a super_admin" do
      users(:super_admin).deployer?.must_equal(true)
    end

    it "is true for an admin" do
      users(:admin).admin?.must_equal(true)
    end

    it "is false for a viewer" do
      User.new.wont_be(:deployer?)
    end
  end

  describe "#viewer?" do
    it "is true for a super_admin" do
      users(:super_admin).viewer?.must_equal(true)
    end

    it "is true for an admin" do
      users(:admin).viewer?.must_equal(true)
    end

    it "is true for a deployer" do
      users(:deployer).viewer?.must_equal(true)
    end

    it "is true for everyone else and by default" do
      User.new.viewer?.must_equal(true)
    end
  end

  describe ".search" do
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

    it 'sanitizes query values' do
      User.search('%').must_equal []
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

    it 'returns all results with an empty query' do
      User.search('').count.must_equal(User.count)
    end

    it 'returns all results with a nil query' do
      User.search(nil).count.must_equal(User.count)
    end
  end

  describe ".with_role" do
    let(:project) { projects(:test) }
    let(:deployer_list) do
      [
        "Admin",
        "Deployer",
        "Deployer Project Admin",
        "DeployerBuddy",
        "Project Deployer",
        "Super Admin"
      ]
    end

    it "filters everything when asking for a unreachable role" do
      User.with_role(Role::SUPER_ADMIN.id + 1, project.id).size.must_equal 0
    end

    it "filters nothing when asking for anything" do
      User.with_role(Role::VIEWER.id, project.id).size.must_equal User.count
    end

    it 'filters by deployer' do
      User.with_role(Role::DEPLOYER.id, project.id).map(&:name).sort.must_equal \
        deployer_list
    end

    it 'filters by admin' do
      User.with_role(Role::ADMIN.id, project.id).map(&:name).sort.must_equal \
        ["Admin", "Deployer Project Admin", "Super Admin"]
    end

    describe "with another project" do
      let(:other) do
        p = project.dup
        p.name = 'xxxxx'
        p.save!(validate: false)
        p
      end

      it 'does not show duplicate when multiple roles exist' do
        UserProjectRole.create!(user: users(:project_admin), project: other, role_id: Role::ADMIN.id)
        User.with_role(Role::DEPLOYER.id, project.id).map(&:name).sort.must_equal \
          deployer_list
      end

      it 'shows users that only have a role on different projects' do
        UserProjectRole.create!(user: users(:deployer), project: other, role_id: Role::ADMIN.id)
        User.with_role(Role::DEPLOYER.id, project.id).map(&:name).sort.must_equal \
          deployer_list
      end
    end
  end

  describe 'soft delete!' do
    let(:user) { User.create!(name: 'to_delete', email: 'to_delete@test.com') }
    let!(:locks) do
      %i[test_staging test_production].map { |stage| user.locks.create!(stage: stages(stage)) }
    end

    it 'soft deletes all the user locks when the user is soft deleted' do
      user.soft_delete!
      locks.each { |lock| lock.reload.deleted_at.wont_be_nil }
    end
  end

  describe "#admin_for_project?" do
    it "is true for a user that has been granted the role of project admin" do
      users(:project_admin).admin_for?(projects(:test)).must_equal(true)
    end

    it "is true for a user that are admins" do
      users(:admin).admin_for?(projects(:test)).must_equal(true)
      users(:super_admin).admin_for?(projects(:test)).must_equal(true)
    end

    it "is false for users that have not been granted the role of project admin" do
      users(:viewer).admin_for?(projects(:test)).must_equal(false)
      users(:deployer).admin_for?(projects(:test)).must_equal(false)
    end
  end

  describe "#deployer_for_project?" do
    it "is true for a user that has been granted the role of project deployer" do
      users(:project_deployer).deployer_for?(projects(:test)).must_equal(true)
    end

    it "is true for a user that has been granted the role of project admin" do
      users(:project_admin).deployer_for?(projects(:test)).must_equal(true)
    end

    it "is false for users that have not been granted the roles of project deployer or project admin" do
      users(:viewer).deployer_for?(projects(:test)).must_equal(false)
    end

    it "is true for deployers" do
      users(:deployer).deployer_for?(projects(:test)).must_equal(true)
      users(:admin).deployer_for?(projects(:test)).must_equal(true)
      users(:super_admin).deployer_for?(projects(:test)).must_equal(true)
    end
  end

  describe "#project_role_for" do
    it "returns the project role for the given project" do
      users(:project_admin).project_role_for(projects(:test)).must_equal user_project_roles(:project_admin)
    end
  end

  describe "#starred_project?" do
    let(:user) { users(:viewer) }
    let(:project) { projects(:test) }

    it "is true when starred" do
      user.stars.create!(project: project)
      user.starred_project?(project).must_equal true
    end

    it "is false when not starred" do
      user.starred_project?(project).must_equal false
    end

    it "is cached" do
      user.stars.expects(:pluck).returns []
      user.starred_project?(project).must_equal false
      user.stars.expects(:pluck).never
      user.starred_project?(project).must_equal false
    end

    it "expires the cache when a new star is created" do
      user.starred_project?(project).must_equal false
      user.stars.create!(project: project)
      user.starred_project?(project).must_equal true
    end

    it "expires the cache when a star is deleted" do
      star = user.stars.create!(project: project)
      user.starred_project?(project).must_equal true
      star.destroy
      user.starred_project?(project).must_equal false
    end
  end

  describe "versioning" do
    let(:user) { users(:admin) }

    around { |t| PaperTrail.with_logging(&t) }

    it "tracks important changes" do
      user.update_attributes!(name: "Foo")
      user.versions.size.must_equal 1
    end

    it "ignores unimportant changes" do
      user.update_attributes!(updated_at: 1.second.from_now)
      user.versions.size.must_equal 0
    end

    it "ignores sensitive changes" do
      user.update_attributes!(token: 'secret')
      user.versions.size.must_equal 0
    end

    it "records project_roles change" do
      UserProjectRole.create!(project: projects(:test), user: user, role_id: 1)
      user.versions.size.must_equal 1
      YAML.load(user.versions.first.object)['project_roles'].must_equal "foo" => 1
    end

    it "records project_roles destruction" do
      role = UserProjectRole.create!(project: projects(:test), user: user, role_id: 1)
      role.reload
      role.destroy
      user.versions.size.must_equal 2
      YAML.load(user.versions.last.object)['project_roles'].must_equal({})
    end
  end

  describe "#name_and_email" do
    it "is name and email" do
      users(:admin).name_and_email.must_equal "Admin (admin@example.com)"
    end
  end
end

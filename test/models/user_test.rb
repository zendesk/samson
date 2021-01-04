# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe User do
  describe "#name" do
    let(:user) { User.new(name: username, email: 'test@test.com', external_id: 'xyz') }

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

  describe 'github username' do
    let(:user) { User.create!(name: 'github', email: 'github@test.com', external_id: 'xyz', github_username: 'foo') }
    it 'updates with valid username' do
      user.github_username.must_equal 'foo'
    end

    it 'doesn`t update with invalid username' do
      user.github_username = 'foo_5$'
      refute user.valid?
    end

    it 'validates uniqueness for username' do
      User.create!(name: "Mr.2", email: "2@example.com", external_id: "1232", github_username: 'bar')
      user.github_username = 'bar'
      refute user.valid?
    end
  end

  describe "#time_format" do
    let(:user) { User.create!(name: "jimbob", email: 'test@test.com', external_id: 'xyz') }

    it "has a default time format of relative" do
      user.time_format.must_equal('relative')
    end

    it "does not update with invalid values" do
      user.time_format = 'foobar'
      refute user.valid?
    end

    it "does update with valid values" do
      user.update!(time_format: 'utc')
      user.reload
      user.time_format.must_equal('utc')
    end

    it "allows initialization with different time_format" do
      local_user = User.create!(name: "bettysue", email: 'bsue@test.com', time_format: 'local', external_id: 'xyz')
      local_user.time_format.must_equal('local')
    end
  end

  describe "#gravatar url" do
    let(:user) { User.new(name: "User Name", email: email, external_id: 'xyz') }

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
      User.create!(name: 'FindMe', email: 'find.me@example.org', external_id: 'xyz')
    end

    let!(:some_similar_users) do
      (1..3).map do |index|
        User.create!(name: "TestUser#{index}", email: "some_email#{index}@example.org", external_id: "x-#{index}")
      end
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

  describe ".search_by_criteria" do
    it "can filter by system level role" do
      User.search_by_criteria(search: "", role_id: Role::ADMIN.id).sort.must_equal(
        [users(:admin), users(:super_admin)].sort
      )
    end

    it "can filter by system level role and project role" do
      User.search_by_criteria(search: "", role_id: Role::ADMIN.id, project_id: projects(:test).id).sort.must_equal(
        [users(:admin), users(:super_admin), users(:project_admin)].sort
      )
    end

    it "can filter by email" do
      user = users(:admin)
      User.search_by_criteria(search: "", email: user.email).map(&:name).must_equal [user.name]
    end

    it "can filter by github username" do
      user = users(:github_viewer)
      User.search_by_criteria(github_username: user.github_username).map(&:name).must_equal [user.name]
    end

    it "ignores empty integration" do
      User.search_by_criteria(search: "", integration: "").map(&:name).sort.must_equal User.all.map(&:name).sort
    end

    it "can filter by integration" do
      user = users(:admin)
      user.update_column :integration, true
      User.search_by_criteria(search: "", integration: 'true').map(&:name).must_equal [user.name]
    end

    it "can filter by integration from api" do
      user = users(:admin)
      user.update_column :integration, true
      User.search_by_criteria(search: "", integration: false).map(&:name).sort.
        must_equal User.all.map(&:name).sort - [user.name]
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
        p.permalink = 'xxxxx'
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
    let(:user) { User.create!(name: 'to_delete', email: 'to_delete@test.com', external_id: 'xyz') }
    let!(:locks) do
      [:test_staging, :test_production].map { |stage| user.locks.create!(resource: stages(stage)) }
    end

    it 'soft deletes all the user locks when the user is soft deleted' do
      user.soft_delete!(validate: false)
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

    it "returns nil without a project" do
      user = users(:project_admin)
      assert_sql_queries 0 do
        user.project_role_for(nil).must_equal nil
      end
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
      user.stars.delete_all
      user.starred_project?(project).must_equal false
      users(:admin).stars.create!(project: project).update_column(:user_id, user.id)
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

  describe "auditing" do
    let(:user) { users(:admin) }

    it "tracks important changes" do
      user.update!(name: "Foo")
      user.audits.size.must_equal 1
    end

    it "ignores unimportant changes" do
      user.update!(updated_at: 1.second.from_now, last_login_at: Time.now)
      user.audits.size.must_equal 0
    end

    it "records project_roles change" do
      UserProjectRole.create!(project: projects(:test), user: user, role_id: 1)
      user.audits.size.must_equal 1
      user.audits.first.audited_changes.must_equal("user_project_roles" => [{}, {"foo" => 1}])
    end

    it "records project_roles destruction" do
      role = UserProjectRole.create!(project: projects(:test), user: user, role_id: 1)
      role.reload
      role.destroy
      user.audits.size.must_equal 2
      user.audits.last.audited_changes.must_equal("user_project_roles" => [{"foo" => 1}, {}])
    end
  end

  describe "#name_and_email" do
    let(:user) { users(:admin) }

    it "is name and email" do
      user.name_and_email.must_equal "Admin (admin@example.com)"
    end

    it "is email without name" do
      user.name = ''
      user.name_and_email.must_equal "admin@example.com"
    end
  end

  describe "#user_project_roles" do
    let(:user) { users(:project_admin) }

    it "deletes them on deletion and audits as user change" do
      assert_difference 'Audited::Audit.where(auditable_type: "User").count', +2 do
        assert_difference 'UserProjectRole.count', -1 do
          user.soft_delete!(validate: false)
        end
      end
    end
  end
end

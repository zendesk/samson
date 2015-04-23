require_relative '../test_helper'

describe Project do
  let(:project) { projects(:test) }
  let(:author) { users(:deployer) }
  let(:url) { "git://foo.com:hello/world.git" }

  def clone_repository(project)
    Project.any_instance.unstub(:clone_repository)
    project.send(:clone_repository).join
  end

  before { Project.any_instance.stubs(:valid_repository_url).returns(true) }

  it "generates a secure token when created" do
    Project.create!(name: "hello", repository_url: url).token.wont_be_nil
  end

  describe "#last_released_with_commit?" do
    it "returns true if the last release had that commit" do
      project.releases.create!(commit: "XYZ", author: author)
      assert project.last_released_with_commit?("XYZ")
    end

    it "returns false if the last release had a different commit" do
      project.releases.create!(commit: "123", author: author)
      assert !project.last_released_with_commit?("XYZ")
    end

    it "returns false if there have been no releases" do
      refute project.last_released_with_commit?("XYZ")
    end
  end

  it "has separate repository_directories for same project but different url" do
    project = projects(:test)
    other_project = Project.find(project.id)
    other_project.repository_url = 'git://hello'

    assert_not_equal project.repository_directory, other_project.repository_directory
  end

  describe "#webhook_stages_for" do
    it "returns the stages with mappings for the branch" do
      master_stage = project.stages.create!(name: "master_stage")
      production_stage = project.stages.create!(name: "production_stage")

      project.webhooks.create!(branch: "master", stage: master_stage, source: 'any')
      project.webhooks.create!(branch: "production", stage: production_stage, source: 'travis')

      project.webhook_stages_for("master", "ci", "jenkins").must_equal [master_stage]
      project.webhook_stages_for("production", "ci", "travis").must_equal [production_stage]
    end
  end

  describe "#github_project" do
    it "returns the user/repo part of the repository URL" do
      project = Project.new(repository_url: "git@github.com:foo/bar.git")
      project.github_repo.must_equal "foo/bar"
    end

    it "handles user, organisation and repository names with hyphens" do
      project = Project.new(repository_url: "git@github.com:inlight-media/lighthouse-ios.git")
      project.github_repo.must_equal "inlight-media/lighthouse-ios"
    end

    it "handles repository names with dashes or dots" do
      project = Project.new(repository_url: "git@github.com:angular/angular.js.git")
      project.github_repo.must_equal "angular/angular.js"

      project = Project.new(repository_url: "git@github.com:zendesk/demo_apps.git")
      project.github_repo.must_equal "zendesk/demo_apps"
    end

    it "handles https urls" do
      project = Project.new(repository_url: "https://github.com/foo/bar.git")
      project.github_repo.must_equal "foo/bar"
    end
  end

  describe "nested stages attributes" do
    let(:params) do
      {
        name: "Hello",
        repository_url: url,
        stages_attributes: {
          '0' => {
            name: 'Production',
            command: 'test command',
            command_ids: [commands(:echo).id]
          }
        }
      }
    end

    it 'creates a new project and stage'do
      project = Project.create!(params)
      stage = project.stages.where(name: 'Production').first
      stage.wont_be_nil
      stage.command.must_equal("echo hello\ntest command")
    end
  end

  describe 'project repository initialization' do
    let(:repository_url) { 'git@github.com:zendesk/demo_apps.git' }

    it 'should not clean the project when the project is created' do
      project = Project.new(name: 'demo_apps', repository_url: repository_url)
      project.expects(:clean_old_repository).never
      project.save
    end

    it 'invokes the setup repository callback after creation' do
      project = Project.new(name: 'demo_apps', repository_url: repository_url)
      project.expects(:clone_repository).once
      project.save
    end

    it 'removes the cached repository after the project has been deleted' do
      project = Project.new(name: 'demo_apps', repository_url: repository_url)
      project.expects(:clone_repository).once
      project.expects(:clean_repository).once
      project.save
      project.soft_delete!
    end

    it 'removes the old repository and sets up the new repository if the repository_url is updated' do
      new_repository_url = 'git@github.com:angular/angular.js.git'
      project = Project.create(name: 'demo_apps', repository_url: repository_url)
      project.expects(:clone_repository).once
      original_repo_dir = project.repository.repo_cache_dir
      FileUtils.expects(:rm_rf).with(original_repo_dir).once
      project.update!(repository_url: new_repository_url)
      refute_equal(original_repo_dir, project.repository.repo_cache_dir)
    end

    it 'does not reset the repository if the repository_url is not changed' do
      project = Project.new(name: 'demo_apps', repository_url: repository_url)
      project.expects(:clone_repository).once
      project.expects(:clean_old_repository).never
      project.save!
      project.update!(name: 'new_name')
    end

    it 'sets the git repository on disk' do
      repository = mock()
      repository.expects(:clone!).once
      project = Project.new(id: 9999, name: 'demo_apps', repository_url: repository_url)
      project.stubs(:repository).returns(repository)
      clone_repository(project)
    end

    it 'fails to clone the repository and logs the error' do
      repository = mock()
      repository.expects(:clone!).returns(false).once
      project = Project.new(id: 9999, name: 'demo_apps', repository_url: repository_url)
      project.stubs(:repository).returns(repository)
      expected_message = "Could not clone git repository #{project.repository_url} for project #{project.name} - "
      Rails.logger.expects(:error).with(expected_message)
      clone_repository(project)
    end

    it 'logs that it could not clone the repository when there is an unexpected error' do
      error = 'Unexpected error while cloning the repository'
      repository = mock()
      repository.expects(:clone!).raises(error)
      project = Project.new(id: 9999, name: 'demo_apps', repository_url: repository_url)
      project.stubs(:repository).returns(repository)
      expected_message = "Could not clone git repository #{project.repository_url} for project #{project.name} - #{error}"
      Rails.logger.expects(:error).with(expected_message)
      clone_repository(project)
    end

    it 'does not validate with a bad repo url' do
      Project.any_instance.unstub(:valid_repository_url)
      project = Project.new(id: 9999, name: 'demo_apps', repository_url: 'my_bad_url')
      project.valid?.must_equal false
      project.errors.messages.must_equal repository_url: ["is not valid or accessible"]
    end
  end

  describe 'lock project' do

    let(:repository_url) { 'git@github.com:zendesk/demo_apps.git' }
    let(:project_id) { 999999 }

    after(:each) do
      MultiLock.locks = {}
    end

    it 'locks the project' do
      project = Project.new(id: project_id, name: 'demo_apps', repository_url: repository_url)
      output = StringIO.new
      MultiLock.locks[project_id].must_be_nil
      project.with_lock(output: output, holder: 'test', timeout: 2.seconds) do
        MultiLock.locks[project_id].wont_be_nil
      end
      MultiLock.locks[project_id].must_be_nil
    end

    it 'fails to aquire a lock if there is a lock already there' do
      MultiLock.locks = { project_id => 'test' }
      MultiLock.locks[project_id].wont_be_nil
      project = Project.new(id: project_id, name: 'demo_apps', repository_url: repository_url)
      output = StringIO.new
      project.with_lock(output: output, holder: 'test', timeout: 1.seconds) { output.puts("Can't get here") }
      output.string.include?("Can't get here").must_equal(false)
    end

    it 'executes the provided error callback if cannot acquire the lock' do
      MultiLock.locks = { project_id => 'test' }
      MultiLock.locks[project_id].wont_be_nil
      project = Project.new(id: project_id, name: 'demo_apps', repository_url: repository_url)
      output = StringIO.new
      callback = proc { output << 'using the error callback' }
      project.with_lock(output: output, holder: 'test', error_callback: callback, timeout: 1.seconds) do
        output.puts("Can't get here")
      end
      MultiLock.locks[project_id].wont_be_nil
      output.string.include?('using the error callback').must_equal(true)
      output.string.include?("Can't get here").must_equal(false)
    end
  end

  describe '#last_deploy_by_group' do
    let(:pod1) { deploy_groups(:pod1) }
    let(:pod2) { deploy_groups(:pod2) }
    let(:pod100) { deploy_groups(:pod100) }
    let(:prod_deploy) { deploys(:succeeded_production_test) }
    let(:staging_deploy) { deploys(:succeeded_test) }
    let!(:user) { users(:deployer) }

    it 'contains releases per deploy group' do
      deploys = project.last_deploy_by_group(Time.now)
      deploys[pod1.id].must_equal prod_deploy
      deploys[pod2.id].must_equal prod_deploy
      deploys[pod100.id].must_equal staging_deploy
    end

    it "does not contain releases after requested time" do
      staging_deploy.update_column(:updated_at, prod_deploy.updated_at - 2.days)
      deploys = project.last_deploy_by_group(prod_deploy.updated_at - 1.day)
      deploys[pod1.id].must_equal nil
      deploys[pod2.id].must_equal nil
      deploys[pod100.id].must_equal staging_deploy
    end

    it 'contains no releases for undeployed projects' do
      project = Project.create!(name: 'blank_new_project', repository_url: url)
      deploys = project.last_deploy_by_group(Time.now)
      deploys[pod1.id].must_be_nil
      deploys[pod2.id].must_be_nil
      deploys[pod100.id].must_be_nil
    end

    it 'performs minimal number of queries' do
      Project.create!(name: 'blank_new_project', repository_url: url)
      assert_sql_queries 7 do
        Project.ordered_for_user(user).with_deploy_groups.each do |p|
          p.last_deploy_by_group(Time.now)
        end
      end
    end
  end

  describe '#ordered_for_user' do
    it 'returns unstarred projects in alphabetical order' do
      Project.create!(name: 'A', repository_url: url)
      Project.create!(name: 'Z', repository_url: url)
      Project.ordered_for_user(author).map(&:name).must_equal ['A', 'Project', 'Z']
    end

    it 'returns starred projects in alphabetical order' do
      Project.create!(name: 'A', repository_url: url)
      z = Project.create!(name: 'Z', repository_url: url)
      author.stars.create!(project: z)
      Project.ordered_for_user(author).map(&:name).must_equal ['Z', 'A', 'Project']
    end
  end
end

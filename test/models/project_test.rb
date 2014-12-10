require_relative '../test_helper'

describe Project do
  let(:url) { "git://foo.com:hello/world.git" }

  it "generates a secure token when created" do
    project = Project.new(name: "hello", repository_url: url)
    project.repository.stubs(:setup!).returns(:true)
    project.save!
    project.token.wont_be_nil
  end

  it "has separate repository_directories for same project but different url" do
    project = projects(:test)
    other_project = Project.find(project.id)
    other_project.repository_url = 'git://hello'

    assert_not_equal project.repository_directory, other_project.repository_directory
  end

  describe "#create_release" do
    let(:project) { projects(:test) }
    let(:author) { users(:deployer) }

    it "creates a new release" do
      release = project.create_release(commit: "foo", author: author)

      assert release.persisted?
    end

    it "defaults to release number 1" do
      release = project.create_release(commit: "foo", author: author)

      assert_equal 1, release.number
    end

    it "increments the release number" do
      project.releases.create!(author: author, commit: "bar", number: 41)
      release = project.create_release(commit: "foo", author: author)

      assert_equal 42, release.number
    end
  end

  describe "#changeset_for_release" do
    let(:project) { projects(:test) }
    let(:author) { users(:deployer) }


    it "returns changeset" do
      changeset = Changeset.new("url", "foo/bar", "a", "b")
      project.releases.create!(author: author, commit: "bar", number: 50)
      release = project.create_release(commit: "foo", author: author)

      Changeset.stubs(:find).with("bar/foo", "bar", "foo").returns(changeset)
      assert_equal changeset, project.changeset_for_release(release)
    end

    it "returns empty changeset" do
      changeset = Changeset.new("url", "foo/bar", "a", "a")
      release = project.releases.create!(author: author, commit: "bar", number: 50)

      Changeset.stubs(:find).with("bar/foo", nil, "bar").returns(changeset)
      assert_equal changeset, project.changeset_for_release(release)
    end
  end

  describe "#webhook_stages_for_branch" do
    let(:project) { projects(:test) }

    it "returns the stages with mappings for the branch" do
      master_stage = project.stages.create!(name: "master_stage")
      production_stage = project.stages.create!(name: "production_stage")

      project.webhooks.create!(branch: "master", stage: master_stage)
      project.webhooks.create!(branch: "production", stage: production_stage)

      project.webhook_stages_for_branch("master").must_equal [master_stage]
      project.webhook_stages_for_branch("production").must_equal [production_stage]
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
  end

  describe "nested stages attributes" do
    let(:params) {{
      name: "Hello",
      repository_url: url,
      stages_attributes: {
        '0' => {
          name: 'Production',
          command: 'test command',
          command_ids: [commands(:echo).id]
        }
      }
    }}

    it 'creates a new project and stage'do
      project = Project.new(params)
      project.repository.stubs(:setup!).returns(true)
      project.save!
      stage = project.stages.where(name: 'Production').first
      stage.wont_be_nil
      stage.command.must_equal("echo hello\ntest command")
    end
  end

  describe 'project repository initialization' do

    let(:repository_url) { 'git@github.com:zendesk/demo_apps.git' }

    it 'invokes the setup repository callback after creation' do
      project = Project.new(name: 'demo_apps', repository_url: repository_url)
      project.expects(:setup_repository).once
      project.save
    end

    it 'removes the cached repository after the project has been deleted' do
      project = Project.new(name: 'demo_apps', repository_url: repository_url)
      project.expects(:setup_repository).once
      project.repository.expects(:clean!).once
      project.save
      project.destroy
    end

    it 'removes the old repository and sets up the new repository if the repository_url is updated' do
      project = Project.new(name: 'demo_apps', repository_url: repository_url)
      project.expects(:setup_repository).twice
      project.expects(:clean_repository).once
      project.save!
      project.update!(repository_url: 'git@github.com:angular/angular.js.git')
    end

    it 'does not reset the repository if the repository_url is not changed' do
      project = Project.new(name: 'demo_apps', repository_url: repository_url)
      project.expects(:setup_repository).twice
      project.expects(:clean_repository).once
      project.save!
      project.update!(name: 'new_name')
    end

    it 'sets the git repository on disk' do
      repository = mock()
      repository.expects(:setup!).once
      project = Project.new(id: 9999, name: 'demo_apps', repository_url: repository_url)
      project.stubs(:repository).returns(repository)
      project.send(:setup_repository).join
    end

    it 'fails to setup the repository and logs the error' do
      repository = mock()
      repository.expects(:setup!).returns(false).once
      project = Project.new(id: 9999, name: 'demo_apps', repository_url: repository_url)
      project.stubs(:repository).returns(repository)
      expected_message = "Could not setup git repository #{project.repository_url} for project #{project.name} - "
      Rails.logger.expects(:error).with(expected_message)
      project.send(:setup_repository).join
    end

    it 'logs that it could not setup the repository when there is an unexpected error' do
      error = 'Unexpected error while setting up the repository'
      repository = mock()
      repository.expects(:setup!).raises(error)
      project = Project.new(id: 9999, name: 'demo_apps', repository_url: repository_url)
      project.stubs(:repository).returns(repository)
      expected_message = "Could not setup git repository #{project.repository_url} for project #{project.name} - #{error}"
      Rails.logger.expects(:error).with(expected_message)
      project.send(:setup_repository).join
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
      project.lock_me(output: output, owner: 'test', timeout: 2.seconds) do
        MultiLock.locks[project_id].wont_be_nil
      end
      MultiLock.locks[project_id].must_be_nil
    end

    it 'fails to aquire a lock if there is a lock already there' do
      MultiLock.locks = { project_id => 'test' }
      MultiLock.locks[project_id].wont_be_nil
      project = Project.new(id: project_id, name: 'demo_apps', repository_url: repository_url)
      output = StringIO.new
      project.lock_me(output: output, owner: 'test', timeout: 1.seconds) { output.puts("Can't get here") }
      output.string.must_equal('')
    end

    it 'executes the provided error callback if cannot aquire the lock' do
      MultiLock.locks = { project_id => 'test' }
      MultiLock.locks[project_id].wont_be_nil
      project = Project.new(id: project_id, name: 'demo_apps', repository_url: repository_url)
      output = StringIO.new
      callback = Proc.new { output << 'using the error callback' }
      project.lock_me(output: output, owner: 'test', error_callback: callback, timeout: 1.seconds) do
        output.puts("Can't get here")
      end
      MultiLock.locks[project_id].wont_be_nil
      output.string.must_equal('using the error callback')
    end

  end

end

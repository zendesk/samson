require_relative '../test_helper'

describe Project do
  let(:project) { projects(:test) }
  let(:author) { users(:deployer) }
  let(:url) { "git://foo.com:hello/world.git" }

  it "generates a secure token when created" do
    project = Project.create!(name: "hello", repository_url: url)
    project.token.wont_be_nil
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

    it "returns false if there have been no releases" do
      assert !project.last_released_with_commit?("XYZ")
    end
  end

  describe "#create_release" do
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
      project = Project.create!(params)
      stage = project.stages.where(name: 'Production').first
      stage.wont_be_nil
      stage.command.must_equal("echo hello\ntest command")
    end
  end
end

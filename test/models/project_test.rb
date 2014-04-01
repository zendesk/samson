require_relative '../test_helper'

describe Project do
  it "generates a secure token when created" do
    project = Project.create!(name: "hello", repository_url: "world")
    project.token.wont_be_nil
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
    Changeset = MiniTest::Mock.new

    it "returns changeset" do
      project.releases.create!(author: author, commit: "bar", number: 50)
      release = project.create_release(commit: "foo", author: author)

      Changeset.expect :find, 1, [ "bar/foo", "bar", "foo"]

      refute_nil project.changeset_for_release(release)
    end

    it "returns empty changeset" do
      release = project.releases.create!(author: author, commit: "bar", number: 50)

      Changeset.expect :find, 1, [ "bar/foo", nil, "bar"]

      refute_nil project.changeset_for_release(release)
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
  end

  describe "nested stages attributes" do
    let(:params) {{
      name: "Hello",
      repository_url: "git://foo.com/bar",
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

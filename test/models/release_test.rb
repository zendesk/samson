require_relative '../test_helper'

SingleCov.covered! uncovered: 4

describe Release do
  describe "create" do
    let(:project) { projects(:test) }
    let(:author) { users(:deployer) }
    let(:commit) { "abcd" }

    it "creates a new release" do
      release = project.releases.create!(commit: commit, author: author)
      assert_equal 124, release.number
    end

    it "increments the release number" do
      release = project.releases.create!(author: author, commit: "bar")
      release.update_column(:number, 41)
      release = project.releases.create!(commit: "foo", author: author)
      assert_equal 42, release.number
    end
  end

  describe "#currently_deploying_stages" do
    let(:project) { projects(:test) }
    let(:author) { users(:deployer) }
    let(:stage) { project.stages.create!(name: "One") }
    let(:release) do
      release = project.releases.create!(author: author, commit: "xyz")
      release.update_column(:number, 42)
      release
    end

    it "returns stages where the release is pending deploy" do
      create_deploy!(reference: "v42", status: "pending")
      assert_equal [stage], release.currently_deploying_stages
    end

    it "returns stages where the release is currently being deployed" do
      create_deploy!(reference: "v42", status: "running")
      assert_equal [stage], release.currently_deploying_stages
    end

    it "returns stages where a deploy of the release is being cancelled" do
      create_deploy!(reference: "v42", status: "cancelling")
      assert_equal [stage], release.currently_deploying_stages
    end

    it "ignores stages where there are no current deploys" do
      create_deploy!(reference: "v42", status: "succeeded")
      assert_equal [], release.currently_deploying_stages
    end

    it "ignores stages where another release is being deployed" do
      create_deploy!(reference: "v666", status: "running")
      assert_equal [], release.currently_deploying_stages
    end

    it "handles deleted author" do
      create_deploy!(reference: "v666", status: "succeeded")
      author.soft_delete!
      release.reload
      assert_equal author.name, release.author.name
    end

    it "handles deleted author" do
      create_deploy!(reference: "v666", status: "succeeded")
      author.destroy!
      release.reload
      assert_equal NullUser.new(0).name, release.author.name
    end

    def create_deploy!(options)
      job = project.jobs.create!(user: author, commit: "x", command: "yes", status: options.fetch(:status))
      stage.deploys.create!(reference: options.fetch(:reference), job: job)
    end
  end

  describe "#changeset" do
    let(:project) { projects(:test) }
    let(:author) { users(:deployer) }

    it "returns changeset" do
      release = project.releases.create!(commit: "foo", author: author)
      assert_equal 'abc...foo', release.changeset.commit_range
    end

    it 'returns empty changeset when there is no prior release' do
      Release.delete_all
      release = project.releases.create!(author: author, commit: "bar")

      assert_equal 'bar...bar', release.changeset.commit_range
      assert_equal [], release.changeset.commits
    end
  end
end

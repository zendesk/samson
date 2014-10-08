require_relative '../test_helper'

describe Release do
  describe "#currently_deploying_stages" do
    let(:project) { projects(:test) }
    let(:author) { users(:deployer) }
    let(:stage) { project.stages.create!(name: "One") }
    let(:release) { project.releases.create!(number: 42, author: author, commit: "xyz") }

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
      assert_equal NullUser.new.name, release.author.name
    end

    def create_deploy!(reference:, status:)
      job = project.jobs.create!(user: author, commit: "x", command: "yes", status: status)
      stage.deploys.create!(reference: reference, job: job)
    end
  end
end

require 'test_helper'

describe Deploy do
  let(:project) { projects(:test) }
  let(:user) { users(:deployer) }
  let(:stage) { stages(:test_staging) }

  describe "#previous_deploy" do
    it "returns the deploy prior to that deploy" do
      deploy1 = stage.deploys.create!(reference: "foo", job: create_job!)
      deploy2 = stage.deploys.create!(reference: "bar", job: create_job!)

      deploy2.previous_deploy.must_equal deploy1
    end
  end

  describe ".prior_to" do
    it "scopes the records to deploys prior to the one passed in" do
      deploy1 = stage.deploys.create!(reference: "foo", job: create_job!)
      deploy2 = stage.deploys.create!(reference: "bar", job: create_job!)
      deploy3 = stage.deploys.create!(reference: "baz", job: create_job!)

      stage.deploys.prior_to(deploy2).must_equal [deploy1]
    end
  end

  def create_job!
    Job.create!(project: project, command: "echo hello world", user: user)
  end
end

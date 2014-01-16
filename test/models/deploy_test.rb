require_relative '../test_helper'

describe Deploy do
  let(:project) { projects(:test) }
  let(:user) { users(:deployer) }
  let(:stage) { stages(:test_staging) }

  describe "#previous_deploy" do
    it "returns the deploy prior to that deploy" do
      deploy1 = create_deploy!
      deploy2 = create_deploy!
      deploy3 = create_deploy!


      deploy2.previous_deploy.must_equal deploy1
      deploy3.previous_deploy.must_equal deploy2
    end

    it "excludes non-successful deploys" do
      deploy1 = create_deploy!(job: create_job!(status: "succeeded"))
      deploy2 = create_deploy!(job: create_job!(status: "errored"))
      deploy3 = create_deploy!

      deploy3.previous_deploy.must_equal deploy1
    end
  end

  describe ".prior_to" do
    it "scopes the records to deploys prior to the one passed in" do
      deploy1 = create_deploy!
      deploy2 = create_deploy!
      deploy3 = create_deploy!

      stage.deploys.prior_to(deploy2).must_equal [deploy1]
    end
  end

  def create_deploy!(attrs = {})
    default_attrs = {
      reference: "baz",
      job: create_job!
    }

    stage.deploys.create!(default_attrs.merge(attrs))
  end

  def create_job!(attrs = {})
    default_attrs = {
      project: project,
      command: "echo hello world",
      status: "succeeded",
      user: user
    }

    Job.create!(default_attrs.merge(attrs))
  end
end

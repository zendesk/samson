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

  describe "#short_reference" do
    it "returns the first seven characters if the reference looks like a SHA" do
      deploy = Deploy.new(reference: "8e7c20937de160905e8ffb13be72eb483ab4170a")
      deploy.short_reference.must_equal "8e7c209"
    end

    it "returns the full reference if it doesn't look like a SHA" do
      deploy = Deploy.new(reference: "foobarbaz")
      deploy.short_reference.must_equal "foobarbaz"
    end
  end

  describe 'deploy locked stage' do
    before do
      stage.create_lock!(user: user)
    end

    it 'fails' do
      lambda { create_deploy! }.must_raise(ActiveRecord::RecordInvalid)
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

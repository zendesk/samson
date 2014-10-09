require_relative '../test_helper'

describe Deploy do
  let(:project) { projects(:test) }
  let(:user) { users(:deployer) }
  let(:user2) { users(:admin) }
  let(:stage) { stages(:test_staging) }

  describe "#deploy_buddy" do
    setup { @deploy = create_deploy! }

    describe "no buddy message at all" do
      it "returns no buddy name when BuddyCheck is not enabled" do
        BuddyCheck.stubs(:enabled?).returns(false)
        @deploy.summary.must_match(/#{user.name}  deployed/)
      end

      it "returns no buddy if we are not deploying to production" do
        @deploy.stubs(:production?).returns(false)
        @deploy.summary.must_match(/#{user.name}  deployed/)
      end
    end

    describe "when a buddy message should be included" do
      setup do
        BuddyCheck.stubs(:enabled?).returns(true)
        stage.stubs(:production?).returns(true)
        @deploy.stubs(:stage).returns(stage)
      end

      it "returns user name if buddy is soft deleted" do
        @deploy.confirm_buddy!(user2)
        user2.soft_delete!
        @deploy.reload
        @deploy.summary.must_include(user2.name)
      end

      it "returns 'Deleted User' if buddy is hard deleted" do
        @deploy.confirm_buddy!(user2)
        user2.destroy!
        @deploy.reload
        @deploy.summary.must_include(NullUser.new.name)
      end

      it "returns 'waiting for a buddy' when waiting for a buddy" do
        @deploy.stubs(:pending?).returns(true)
        @deploy.summary.must_match(/waiting for a buddy/)
      end

      it "returns 'without a buddy' when bypassed" do
        @deploy.stubs(:buddy).returns(user)
        @deploy.summary.must_match(/without a buddy/)

        @deploy.stubs(:buddy).returns(nil)
        @deploy.summary.must_match(/without a buddy/)
      end

      it "should return the name of the buddy when not bypassed" do
        other_user = users(:deployer_buddy)
        @deploy.stubs(:buddy).returns(other_user)
        @deploy.summary.must_match(/#{other_user.name}/)
      end
    end
  end

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
      Deploy.delete_all
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

    describe 'stage locked by someone else' do
      it 'fails' do
        lambda { create_deploy!(job_attributes: { user: user2 }) }.must_raise(ActiveRecord::RecordInvalid)
      end
    end

    describe 'stage locked by the current user' do
      it 'works' do
        create_deploy!(job_attributes: { user: user })
        Deploy.all.wont_be_empty
      end
    end
  end

  def create_deploy!(attrs = {})
    default_attrs = {
      reference: "baz",
      job: create_job!(attrs.delete(:job_attributes) || {})
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

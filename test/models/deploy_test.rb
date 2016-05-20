require_relative '../test_helper'

SingleCov.covered! uncovered: 38

describe Deploy do
  let(:project) { projects(:test) }
  let(:user) { users(:deployer) }
  let(:user2) { users(:admin) }
  let(:stage) { stages(:test_staging) }
  let(:deploy) { deploys(:succeeded_test) }

  describe "#summary" do
    let!(:deploy) { create_deploy! }

    it "shows no buddy" do
      deploy.summary.must_equal "Deployer  deployed baz to Staging"
    end

    it "shows soft delete user" do
      deploy.user.soft_delete!
      deploy.reload
      deploy.summary.must_equal "Deployer  deployed baz to Staging"
    end

    it "shows hard delete user" do
      deploy.user.delete
      deploy.reload
      deploy.summary.must_equal "Deleted User  deployed baz to Staging"
    end

    describe "when buddy was required" do
      before { Stage.any_instance.stubs(:deploy_requires_approval?).returns true }

      describe "with a buddy" do
        before { deploy.update_column(:buddy_id, user2.id) }

        it "shows the buddy" do
          deploy.summary.must_equal "Deployer (with Admin) deployed baz to Staging"
        end

        it "shows soft delete buddy" do
          deploy.buddy.soft_delete!
          deploy.reload
          deploy.summary.must_equal "Deployer (with Admin) deployed baz to Staging"
        end

        it "shows hard delete buddy" do
          deploy.buddy.delete
          deploy.reload
          deploy.summary.must_equal "Deployer (with Deleted User) deployed baz to Staging"
        end
      end

      it "shows waiting when deploy is pending" do
        deploy.job.status = 'pending'
        deploy.summary.must_equal "Deployer (waiting for a buddy) is about to deploy baz to Staging"
      end

      it "shows that there was no buddy" do
        deploy.summary.must_equal "Deployer (without a buddy) deployed baz to Staging"
      end

      it "shows that there was no buddy when skipping" do
        deploy.buddy = user
        deploy.summary.must_equal "Deployer (without a buddy) deployed baz to Staging"
      end
    end
  end

  describe "#summary_for_process" do
    it "renders" do
      deploy.job.stubs(pid: 123)
      deploy.summary_for_process.gsub(/\d+/, "DD").must_equal "ProcessID: DD Running: DD seconds"
    end
  end

  describe "#summary_for_timeline" do
    it "renders" do
      deploy.summary_for_timeline.must_equal "staging was deployed to Staging"
    end
  end

  describe "#summary_for_email" do
    it "renders" do
      deploy.summary_for_email.must_equal "Super Admin deployed Project to Staging (staging)"
    end
  end

  describe "#commit" do
    before { deploy.job.commit = 'abcdef' }

    it "returns the jobs commit" do
      deploy.commit.must_equal "abcdef"
    end

    it "falls back to deploys reference" do
      deploy.job.commit = nil
      deploy.commit.must_equal "staging"
    end
  end

  describe "#csv_buddy and #buddy_email" do
    before { @deploy = create_deploy! }

    describe "no buddy present" do
      it "returns no email or name" do
        @deploy.stubs(:buddy).returns(nil)
        @deploy.buddy_name.must_be_nil
        @deploy.buddy_email.must_be_nil
      end
    end

    describe "buddy present" do
      it "returns 'bypassed' when bypassed" do
        @deploy.update_attributes(buddy: user)
        @deploy.buddy_name.must_equal "bypassed"
        @deploy.buddy_email.must_equal "bypassed"
      end

      it "returns the name and email of the buddy when not bypassed" do
        other_user = users(:deployer_buddy)
        @deploy.stubs(:buddy).returns(other_user)
        @deploy.buddy_name.must_equal other_user.name
        @deploy.buddy_email.must_equal other_user.email
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
      create_deploy!(job: create_job!(status: "errored"))
      deploy3 = create_deploy!

      deploy3.previous_deploy.must_equal deploy1
    end
  end

  describe ".prior_to" do
    let(:deploys) { Array.new(3).map { create_deploy! } }
    let(:prod_stage) { stages(:test_production) }
    let(:prod_deploy) { create_deploy!(stage: prod_stage) }

    before do
      Deploy.delete_all
      deploys
      prod_deploy
    end

    it "scopes the records to deploys prior to the one passed in" do
      stage.deploys.prior_to(deploys[1]).first.must_equal deploys[0]
    end

    it "does not scope for new deploys" do
      stage.deploys.prior_to(Deploy.new).first.must_equal deploys[2]
    end

    it "properly scopes new deploys to the correct stage" do
      prod_stage.deploys.prior_to(Deploy.new).first.must_equal prod_deploy
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

  describe "#validate_stage_is_unlocked" do
    def deploy!
      create_deploy!(job_attributes: { user: user })
    end

    it("can deploy") { deploy! }

    it "can deploy when locked by myself" do
      stage.create_lock!(user: user)
      deploy!
    end

    it "cannot deploy when locked by someone else" do
      stage.create_lock!(user: user2)
      assert_raise(ActiveRecord::RecordInvalid) { deploy! }
    end

    it "can update a deploy while something else is deployed" do
      create_deploy!(job_attributes: { user: user, status: "running" })
      deploys(:succeeded_test).update_attributes!(buddy_id: 123)
    end
  end

  describe "#validate_stage_uses_deploy_groups_properly" do
    def deploy!
      create_deploy!(job_attributes: { user: user })
    end

    before do
      stage.commands.first.update_column(:command, "echo $DEPLOY_GROUPS")
      DeployGroup.stubs(enabled?: true)
    end

    it "is valid when using $DEPLOY_GROUPS and having deploy groups selected" do
      deploy!
    end

    describe "when not selecting deploy groups" do
      before { stage.deploy_groups.clear }

      it "is invalid" do
        e = assert_raise(ActiveRecord::RecordInvalid) { deploy! }
        e.message.must_equal \
          "Validation failed: Stage contains at least one command using the $DEPLOY_GROUPS " \
          "environment variable, but there are no Deploy Groups associated with this stage."
      end

      it "valid when not using $DEPLOY_GROUPS" do
        DeployGroup.unstub(:enabled?)
        deploy!
      end
    end
  end

  describe "#cache_key" do
    it "includes self and commit" do
      deploys(:succeeded_test).cache_key.must_equal ["deploys/178003093-20140102201000000000000", "staging"]
    end
  end

  describe "trim_reference" do
    it "trims the Git reference" do
      deploy = create_deploy!(reference: " master ")
      deploy.reference.must_equal "master"
    end
  end

  def create_deploy!(attrs = {})
    default_attrs = {
      reference: "baz",
      job: create_job!(attrs.delete(:job_attributes) || {})
    }

    deploy_stage = attrs.delete(:stage) || stage

    deploy_stage.deploys.create!(default_attrs.merge(attrs))
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

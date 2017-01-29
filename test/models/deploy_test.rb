# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

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

    it "shows soft delete stage when INCLUDE_DELETED" do
      deploy.stage.soft_delete!
      deploy.reload
      Stage.with_deleted { deploy.summary.must_equal "Deployer  deployed baz to Staging" }
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

  describe "#job_execution_queue_name" do
    it "queues base on it's stage when it cannot execute in parallel" do
      deploy.job_execution_queue_name.must_equal "stage-#{stage.id}"
    end

    it "does not queue when it can execute in parallel" do
      deploy.stage.run_in_parallel = true
      deploy.job_execution_queue_name.must_be_nil
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

  describe "#buddy_name and #buddy_email" do
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

      it "returns the name and email of the deleted buddy when not bypassed" do
        other_user = users(:deployer_buddy)
        @deploy.stubs(:buddy).returns(other_user)
        users(:deployer_buddy).delete
        @deploy.buddy_name.must_equal other_user.name
        @deploy.buddy_email.must_equal other_user.email
      end
    end
  end

  describe "#previous_deploy" do
    it "finds previous failed deploy" do
      create_deploy!
      deploy2 = create_deploy!(job: create_job!(status: "errored"))
      deploy3 = create_deploy!

      deploy3.previous_deploy.must_equal deploy2
    end
  end

  describe "#previous_successful_deploy" do
    it "returns the deploy prior to that deploy" do
      deploy1 = create_deploy!
      deploy2 = create_deploy!
      deploy3 = create_deploy!

      deploy2.previous_successful_deploy.must_equal deploy1
      deploy3.previous_successful_deploy.must_equal deploy2
    end

    it "excludes non-successful deploys" do
      deploy1 = create_deploy!
      create_deploy!(job: create_job!(status: "errored"))
      deploy3 = create_deploy!

      deploy3.previous_successful_deploy.must_equal deploy1
    end
  end

  describe "#changeset" do
    it "creates a changeset to the previous deploy" do
      deploy.changeset.commit.must_equal "abcabc1"
    end
  end

  describe "#production" do
    it "checks if stage is production" do
      deploy.production.must_equal false
    end
  end

  describe "#bypassed_approval?" do
    before do
      deploy.buddy = deploy.user
      deploy.stage.expects(:deploy_requires_approval?).returns true
    end

    it "is bypassed when the user hits the bypass button" do
      deploy.bypassed_approval?.must_equal true
    end

    it "is not bypassed when the user did not bypass" do
      deploy.buddy = users(:viewer)
      deploy.bypassed_approval?.must_equal false
    end

    it "does not require bypassed_approval" do
      deploy.stage.unstub(:deploy_requires_approval?)
      deploy.bypassed_approval?.must_equal false
    end
  end

  describe "#waiting_for_buddy?" do
    before do
      deploy.stage.stubs(:deploy_requires_approval?).returns true
      deploy.buddy = nil
      deploy.job.status = 'pending'
    end

    it "waits for buddy" do
      deploy.waiting_for_buddy?.must_equal true
    end

    it "does not wait for buddy when it does not require bypassed_approval" do
      deploy.stage.unstub(:deploy_requires_approval?)
      deploy.waiting_for_buddy?.must_equal false
    end

    it "does not wait for buddy when it is not pending" do
      deploy.job.status = 'running'
      deploy.waiting_for_buddy?.must_equal false
    end

    it "does not wait for buddy when it has a buddy" do
      deploy.buddy = users(:viewer)
      deploy.waiting_for_buddy?.must_equal false
    end
  end

  describe "#confirm_buddy!" do
    it "starts the deploy" do
      DeployService.any_instance.expects(:confirm_deploy!)
      deploy.confirm_buddy!(users(:viewer))
      deploy.buddy.must_equal users(:viewer)
    end
  end

  describe ".start_deploys_waiting_for_restart!" do
    before { deploy.job.update_column(:status, 'pending') }

    it "starts deploys that we put on hold" do
      DeployService.any_instance.expects(:confirm_deploy!)
      Deploy.start_deploys_waiting_for_restart!
      deploy.reload
      deploy.updated_at.must_be :>, 2.seconds.ago # did expire caches
      deploy.started_at.must_be :>, 2.seconds.ago # did update started_at
    end

    it "does not start deploys waiting for buddy" do
      Deploy.any_instance.expects(:waiting_for_buddy?).returns(true)
      DeployService.any_instance.expects(:confirm_deploy!).never
      Deploy.start_deploys_waiting_for_restart!
    end
  end

  describe ".active" do
    it "finds all active deploys" do
      deploy.job.update_column(:status, 'running')
      Deploy.active.must_equal [deploy]
    end
  end

  describe ".active_count" do
    it "counts all active deploys" do
      deploy.job.update_column(:status, 'running')
      Deploy.active_count.must_equal 1
    end

    it "caches the result" do
      Deploy.active_count.must_equal 0
      deploy.job.update_column(:status, 'running')
      Deploy.active_count.must_equal 0
    end
  end

  describe ".pending" do
    it "finds all pending deploys" do
      deploy.job.update_column(:status, 'pending')
      Deploy.pending.must_equal [deploy]
    end
  end

  describe ".running" do
    it "finds all running deploys" do
      deploy.job.update_column(:status, 'running')
      Deploy.running.must_equal [deploy]
    end
  end

  describe ".successful" do
    it "finds all succeeded deploys" do
      Deploy.successful.must_equal [deploys(:succeeded_production_test), deploys(:succeeded_test)]
    end
  end

  describe ".finished_naturally" do
    it "finds all succeeded or failed deploys" do
      Deploy.finished_naturally.map(&:id).sort.must_equal(
        [deploys(:succeeded_production_test), deploys(:succeeded_test), deploys(:failed_staging_test)].map(&:id).sort
      )
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

  describe ".expired" do
    let(:threshold) { BuddyCheck.time_limit.minutes.ago }
    let(:other) { deploys(:succeeded_production_test) }

    before do
      deploy.update_column(:buddy_id, nil)
      deploy.job.update_columns(status: 'pending', created_at: threshold + 2)
      other.update_column(:buddy_id, nil)
      other.job.update_columns(status: 'pending', created_at: threshold - 2)
    end

    it "finds all the expired buddy deploys" do
      Deploy.any_instance.expects(:waiting_for_buddy?).returns(true)
      Deploy.expired.must_equal [other]
    end

    it "does not return deploys waiting for samson restart" do
      Deploy.expired.must_equal []
    end
  end

  describe "#url" do
    it 'builds an address for a deploy' do
      deploy.url.must_equal "http://www.test-url.com/projects/foo/deploys/#{deploy.id}"
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
      deploys(:succeeded_test).cache_key.must_equal ["deploys/178003093-20140101201000000000", "abcabc1"]
    end
  end

  describe ".csv_header" do
    it "has as many elements as csv_line does" do
      Deploy.csv_header.size.must_equal deploy.csv_line.size
    end
  end

  describe "csv_line" do
    let(:deployer) { users(:super_admin) }
    let(:other_user) { users(:deployer_buddy) }
    let(:prod) { stages(:test_production) }
    let(:prod_deploy) { deploys(:succeeded_production_test) }
    let(:job) { jobs(:succeeded_production_test) }
    let(:environment) { environments(:production) }

    before do
      Stage.any_instance.stubs(:deploy_requires_approval?).returns true
    end

    describe "with deleted objects" do
      before do
        # replicate worse case scenario where any referenced associations are soft deleted
        prod_deploy.update_attributes(buddy_id: other_user.id)
        prod_deploy.job.user.soft_delete!
        prod_deploy.buddy.soft_delete!
        prod_deploy.stage.deploy_groups.first.environment.soft_delete!
        # next 3 are false soft_deletions: there are dependent destroys that would result in
        # deploy_groups_stages to be cleared which would make this test condition to likely
        # never occur in production but could exist
        prod_deploy.stage.project.update_attribute(:deleted_at, DateTime.new(2016, 1, 1))
        prod_deploy.stage.deploy_groups.first.update_attribute(:deleted_at, DateTime.now)
        prod_deploy.stage.update_attribute(:deleted_at, DateTime.now)
        prod_deploy.reload
      end

      it "returns array with deleted object values with DeployGroups" do
        DeployGroup.stubs(enabled?: true)
        prod.update_attribute(:production, false) # make sure response is from environment

        # the with_deleted calls would be done in CsvJob
        Stage.with_deleted do
          Project.with_deleted do
            DeployGroup.with_deleted do
              Environment.with_deleted do
                prod_deploy.csv_line.must_equal [
                  prod_deploy.id,
                  project.name,
                  prod_deploy.summary,
                  prod_deploy.commit,
                  job.status,
                  prod_deploy.started_at,
                  prod_deploy.finished_at,
                  deployer.name,
                  deployer.email,
                  other_user.name,
                  other_user.email,
                  prod.name,
                  environment.production,
                  !prod.no_code_deployed, # Inverted because report is reporting as code deployed
                  project.deleted_at,
                  prod.deploy_group_names.join('|')
                ]
              end
            end
          end
        end
      end

      it "returns array with deleted object values without DeployGroups" do
        DeployGroup.stubs(enabled?: false)

        # the with_deleted calls would be done in CsvJob
        Stage.with_deleted do
          Project.with_deleted do
            prod_deploy.csv_line.must_equal [
              prod_deploy.id,
              project.name,
              prod_deploy.summary,
              prod_deploy.commit,
              job.status,
              prod_deploy.started_at,
              prod_deploy.finished_at,
              deployer.name,
              deployer.email,
              other_user.name,
              other_user.email,
              prod.name,
              prod.production,
              !prod.no_code_deployed, # Inverted because report is reporting as code deployed
              project.deleted_at,
              ''
            ]
          end
        end
      end
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
      job: create_job!(attrs.delete(:job_attributes) || {}),
      project: project
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

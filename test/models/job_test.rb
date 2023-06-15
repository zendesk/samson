# frozen_string_literal: true
require_relative '../test_helper'
require 'ar_multi_threaded_transactional_tests'

SingleCov.covered!

describe Job do
  include GitRepoTestHelper

  let(:url) { "git://foo.com:hello/world.git" }
  let(:user) { users(:admin) }
  let(:project) { projects(:test) }
  let(:job) { project.jobs.create!(command: 'cat foo', user: user, project: project, commit: 'master') }

  before { Project.any_instance.stubs(:valid_repository_url).returns(true) }

  describe ".valid_status?" do
    it "is valid with known status" do
      assert Job.valid_status?('pending')
    end

    it "is invalid with unknown status" do
      refute Job.valid_status?('foo')
    end
  end

  describe ".non_deploy" do
    it "finds jobs without deploys" do
      Job.non_deploy.must_equal [jobs(:running_test)]
    end
  end

  describe ".pending" do
    it "finds pending jobs" do
      jobs(:running_test).update_column(:status, 'pending')
      Job.pending.must_equal [jobs(:running_test)]
    end
  end

  describe ".running" do
    it "finds running jobs" do
      Job.running.must_equal [jobs(:running_test)]
    end
  end

  describe "#started_by?" do
    it "is started by user" do
      job.started_by?(user).must_equal true
    end

    it "is not started by different user" do
      job.started_by?(users(:viewer)).must_equal false
    end
  end

  describe "#commands" do
    it "splits the commands" do
      job.command = "a\rb\r\nc\nd"
      job.commands.must_equal ["a", "b", "c", "d"]
    end

    it "does not split multiline commands" do
      job.command = "a\\\nb\nc\\\r\nd\re\\f"
      job.commands.must_equal ["a\\\nb", "c\\\nd", "e\\f"]
    end
  end

  describe "#succeeded!" do
    it "marks the job as succeeded" do
      job.succeeded!
      job.status.must_equal "succeeded"
    end
  end

  describe "#failed!" do
    it "shows failed job" do
      job.failed!
      job.status.must_equal "failed"
    end
  end

  describe "#errored!" do
    it "shows errored job" do
      job.errored!
      job.status.must_equal "errored"
    end
  end

  describe "#finished?" do
    it "is finished when it is not active" do
      job.status = "succeeded"
      job.finished?.must_equal true
    end

    it "is not finished when it is active" do
      job.status = "pending"
      job.finished?.must_equal false
    end
  end

  describe "#active?" do
    it "is active when its status is not finished" do
      job.status = "pending"
      job.active?.must_equal true
    end

    it "is not active when its status is finished" do
      job.status = "succeeded"
      job.active?.must_equal false
    end
  end

  describe "#queued?" do
    before do
      JobQueue.stubs(:queued?).returns true
    end

    it "is queued" do
      assert job.queued?
    end

    it "is not queued when not queued" do
      JobQueue.unstub(:queued?)
      refute job.queued?
    end
  end

  describe "#waiting_for_restart??" do
    before { job.status = 'pending' }

    it "is waiting" do
      assert job.waiting_for_restart?
    end

    it "is not waiting when execution is enabled" do
      JobQueue.stubs(:enabled).returns(true)
      refute job.waiting_for_restart?
    end

    it "is not waiting when not pending" do
      job.status = 'running'
      refute job.waiting_for_restart?
    end
  end

  describe "#executing?" do
    it "executing when executing" do
      JobQueue.stubs(:executing?).returns true
      assert job.executing?
    end

    it "not executing when not executing" do
      refute job.executing?
    end
  end

  describe "#output" do
    it "returns an empty string when column is nil" do
      job.update_column :output, nil
      job.output.must_equal ""
    end
  end

  describe "#update_git_references!" do
    it "updates git references" do
      job.update_git_references!(commit: "foo", tag: "bar")
      job.commit.must_equal "foo"
      job.tag.must_equal "bar"
    end

    it "expires the deploy" do
      job.deploy = deploys(:succeeded_test)
      Rails.cache.fetch(job.deploy) { 1 }
      job.update_git_references!(commit: "foo", tag: "bar")
      Rails.cache.fetch(job.deploy) { 2 }.must_equal 2
    end
  end

  describe "#url" do
    it "shows deploy's url when it has a deploy" do
      job.deploy = deploys(:succeeded_test)
      job.url.must_equal "http://www.test-url.com/projects/foo/deploys/#{deploys(:succeeded_test).id}"
    end

    it "shows job's url when it does not have a deploy" do
      job.url.must_equal "http://www.test-url.com/projects/foo/jobs/#{job.id}"
    end
  end

  describe "#validate_globally_unlocked" do
    def create(**args)
      Job.create(command: "", user: user, project: project, **args)
    end

    describe "when globally locked" do
      before { Lock.create!(user: users(:admin)) }

      it 'does not allow a job to be created' do
        create.errors.to_hash.must_equal(base: ['all stages are locked'])
      end

      it 'allows deploys from the lock owner to bypass the lock' do
        create(bypass_global_lock_check: true).errors.to_hash.must_equal({})
      end
    end

    it 'allows a job to be created when warning' do
      Lock.create!(user: users(:admin), warning: true, description: "X")
      create.errors.to_hash.must_equal({})
    end

    it 'allows a job to be created when no locks exist' do
      create.errors.to_hash.must_equal({})
    end
  end

  describe "#summary" do
    it "renders" do
      job.summary.must_equal "Admin is about to execute against master"
    end

    it "shortens the reference when commit is SHA1" do
      job.commit = "a" * 40
      job.summary.must_equal "Admin is about to execute against aaaaaaa"
    end

    it "uses passive voice when the user might not have done it" do
      job.status = "cancelled"
      job.summary.must_equal "Execution by Admin against master is cancelled"

      job.status = "cancelling"
      job.summary.must_equal "Execution by Admin against master is cancelling"
    end
  end

  describe "#user" do
    it "finds regular user" do
      job.user.must_equal user
    end

    it "returns deleted user when user was soft deleted" do
      job.user.soft_delete!(validate: false)
      job.reload.user.must_equal user
    end

    it "returns placeholder user when user was deleted" do
      job.user.delete
      job.reload.user.class.must_equal NullUser
    end
  end

  describe "#pid" do
    with_full_job_execution

    it "has a pid when running" do
      job.command = 'sleep 0.5'
      job_execution = JobExecution.new('master', job)
      JobQueue.perform_later(job_execution)
      sleep 0.5
      job.pid.wont_be_nil
      JobQueue.wait(job_execution.id)
      sleep 0.1
    end

    it "has no pid when not running" do
      job.pid.must_be_nil
    end
  end

  describe "#cancel" do
    with_full_job_execution

    it "cancels an executing job" do
      # get the job running
      ex = JobExecution.new('master', Job.find(job.id)) { sleep 10 }
      JobQueue.perform_later(ex)
      sleep 0.1 # make the job spin up properly
      assert JobQueue.executing?(ex.id)

      # cancel it
      job.cancel(user)
      maxitest_wait_for_extra_threads

      # it is cancelled ?
      assert ex.job.cancelled? # job execution callbacks sets it to cancelled
      ex.job.canceller.must_equal user
    end

    it "cancels an stopped job" do
      refute JobQueue.executing?(job.id)
      job.cancel(user)
      assert job.cancelled?
      job.canceller.must_equal user
    end

    it "does not cancel finished job" do
      job.failed!
      job.cancel(user)
      assert job.failed?
      job.canceller.must_be_nil
    end

    it "cancels a queued job" do
      executing_job = project.jobs.create!(command: 'cat foo', user: user, project: project, commit: 'master')
      executing = JobExecution.new('master', executing_job) { sleep 10 }
      JobQueue.perform_later(executing, queue: 'foo')
      assert JobQueue.executing?(executing.id)

      queued = JobExecution.new('master', job) { sleep 10 }
      JobQueue.perform_later(queued, queue: 'foo')
      assert JobQueue.queued?(queued.id)

      sleep 0.1 # let jobs spin up

      job.cancel(user)
      executing_job.cancel(user)
      maxitest_wait_for_extra_threads

      assert job.cancelled?
      refute JobQueue.queued?(job.id)
      job.canceller.must_equal user
    end

    it "does not change a cancelled job" do
      job.status = "cancelled"
      job.canceller = users(:deployer)
      job.cancel(user)
      job.status.must_equal "cancelled"
      job.canceller.must_equal users(:deployer)
    end

    it "can cancel from application restart" do
      job.cancel(nil)
      job.status.must_equal "cancelled"
      job.canceller.must_be_nil
    end
  end

  describe "#duration" do
    it "shows duration" do
      job.updated_at = job.updated_at + 25
      job.duration.must_equal 25
    end
  end

  describe "#status!" do
    it 'updates' do
      job.update_column(:status, 'pending')

      job.send(:status!, 'succeeded')

      job.status.must_equal 'succeeded'
    end

    it 'reports state' do
      job.expects(:report_state)

      job.send(:status!, 'succeeded')
    end

    it 'does not notify if job is not finished' do
      job.expects(:report_state).never

      job.send(:status!, 'pending')
    end

    it 'updates deploy updated_at' do
      job = jobs(:succeeded_test)
      deploy = job.deploy

      freeze_time do
        deploy.update_column(:updated_at, 1.day.ago)
        deploy.updated_at.wont_equal Time.now

        job.send(:status!, 'succeeded')

        deploy.updated_at.must_equal Time.now
      end
    end
  end

  describe "#report_state" do
    def assert_instrument(with)
      ActiveSupport::Notifications.expects(:instrument).with('job_status.samson', with)
    end

    let(:job) { jobs(:succeeded_test) }

    it 'reports for deploy' do
      assert_instrument(
        stage: job&.deploy&.stage&.permalink,
        kubernetes: job&.deploy&.stage&.kubernetes,
        project: project.permalink,
        type: job&.deploy ? 'deploy' : 'build',
        status: 'succeeded',
        cycle_time: DeployMetrics.new(job&.deploy).cycle_time
      )

      job.send(:report_state)
    end

    it 'reports for build' do
      job = jobs(:running_test) # job without deploy
      job.update_column(:status, 'succeeded')
      assert_instrument(
        stage: job&.deploy&.stage&.permalink,
        kubernetes: job&.deploy&.stage&.kubernetes,
        project: project.permalink,
        type: job&.deploy ? 'deploy' : 'build',
        status: 'succeeded',
        cycle_time: DeployMetrics.new(job&.deploy).cycle_time
      )

      job.send(:report_state)
    end
  end

  describe "#serialize_execution_output" do
    before { freeze_time }

    it "does nothing when finished" do
      job.output = "X"
      job.serialize_execution_output
      job.output.must_equal "X"
    end

    it "serialized execution" do
      execution = JobExecution.new("master", job)
      job.stubs(:execution).returns(execution)
      execution.output.puts "X"
      job.serialize_execution_output
      job.output.must_equal "[04:05:06] X\n"
    end
  end
end

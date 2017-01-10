# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: 15

describe Job do
  include GitRepoTestHelper

  let(:url) { "git://foo.com:hello/world.git" }
  let(:user) { users(:admin) }
  let(:project) { Project.create!(name: 'jobtest', repository_url: url) }
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

  describe "#validate_globally_unlocked" do
    def create
      Job.create(command: "", user: user, project: project)
    end

    it 'does not allow a job to be created when locked' do
      Lock.create!(user: users(:admin))
      create.errors.to_h.must_equal(base: 'all stages are locked')
    end

    it 'allows a job to be created when warning' do
      Lock.create!(user: users(:admin), warning: true, description: "X")
      create.errors.to_h.must_equal({})
    end

    it 'allows a job to be created when no locks exist' do
      create.errors.to_h.must_equal({})
    end
  end

  describe "#summary" do
    it "renders" do
      job.summary.must_equal "Admin is about to execute against master"
    end
  end

  describe "#user" do
    it "finds regular user" do
      job.user.must_equal user
    end

    it "returns deleted user when user was soft deleted" do
      job.user.soft_delete!
      job.reload.user.must_equal user
    end

    it "returns placeholder user when user was deleted" do
      job.user.delete
      job.reload.user.class.must_equal NullUser
    end
  end

  describe "#pid" do
    with_job_execution

    it "has a pid when running" do
      job_execution = JobExecution.new('master', job)
      job_execution.expects(:start!)
      JobExecution.start_job(job_execution)
      JobExecution.any_instance.stubs(:pid).returns(1234)
      job.run!
      job.pid.wont_be_nil
    end

    it "has no pid when not running" do
      job.pid.must_be_nil
    end
  end

  describe "#stop!" do
    # tested with ugly stubs since real execution works in multiple threads which breaks tests
    with_job_execution

    it "stops an active job" do
      ex = stub(start!: true, on_complete: true, id: job.id)
      JobExecution.start_job(ex)
      assert JobExecution.active?(ex.id)

      ex.expects(:stop!)
      job.stop!

      assert job.cancelling? # job execution callbacks would set it to cancelled
    end

    it "stops an inactive job" do
      refute JobExecution.active?(job.id)
      job.stop!
      assert job.cancelled?
    end

    it "stops a queued job" do
      active = stub(start!: true, on_complete: true, id: 123)
      JobExecution.start_job(active, queue: 'foo')

      queued = stub(start!: true, on_complete: true, id: job.id)
      JobExecution.start_job(queued, queue: 'foo')
      assert JobExecution.queued?(queued.id)

      job.stop!

      assert job.cancelled?
      refute JobExecution.queued?(job.id)
    end
  end
end

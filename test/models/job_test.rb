# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: 36

describe Job do
  include GitRepoTestHelper

  let(:url) { "git://foo.com:hello/world.git" }
  let(:user) { users(:admin) }
  let(:project) { Project.create!(name: 'jobtest', repository_url: url) }
  let(:job) { project.jobs.create!(command: 'cat foo', user: user, project: project) }

  before { Project.any_instance.stubs(:valid_repository_url).returns(true) }

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

  describe "#pid" do
    with_job_execution

    before do
      job_execution = JobExecution.new('master', job)
      job_execution.expects(:start!)
      JobExecution.start_job(job_execution)
      JobExecution.any_instance.stubs(:pid).returns(1234)
    end

    it "has a pid when running" do
      job.run!
      job.pid.wont_be_nil
    end

    it "has no pid when stopped" do
      job.stop!
      job.pid.must_be_nil
    end
  end
end

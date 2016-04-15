require_relative '../test_helper'

SingleCov.covered! uncovered: 37

describe Job do
  include GitRepoTestHelper

  before { Project.any_instance.stubs(:valid_repository_url).returns(true) }
  let(:url) { "git://foo.com:hello/world.git" }
  let(:user) { User.create!(name: 'test') }
  let(:project) { Project.create!(name: 'jobtest', repository_url: url) }
  let(:job) { project.jobs.create!(command: 'cat foo', user: user, project: project) }

  describe 'when project is globally locked' do
    before do
      Lock.create!(user: users(:admin))
    end

    it 'does not allow a job to be created' do
      Job.create.errors[:project].must_equal(['is locked'])
    end
  end

  describe "looking for the pid of a job" do
    before do
      JobExecution.start_job(JobExecution.new('master', job))
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

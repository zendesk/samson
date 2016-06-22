# rubocop:disable Metrics/LineLength
require_relative '../../test_helper'

SingleCov.covered! uncovered: 16

describe Kubernetes::Job do
  let(:stage) { stages(:test_staging) }
  let(:task)  { kubernetes_tasks(:db_migrate) }
  let(:statuses) { Kubernetes::Job::VALID_STATUSES }
  let(:build)  { builds(:docker_build) }
  let(:user) { users(:deployer) }
  let(:job) do
    Kubernetes::Job.create!(
      stage: stage,
      kubernetes_task: task,
      status: statuses.first,
      commit: build.git_sha,
      build: build,
      user: user
    )
  end


  before { kubernetes_fake_job_raw_template }

  describe 'validations' do
    it 'is valid by default' do
      assert_valid job
    end

    it 'test validity of status' do
      statuses.each do |status|
        assert_valid job.tap { |kr| kr.status = status }
      end
      refute_valid job.tap { |kr| kr.status = 'foo' }
      refute_valid job.tap { |kr| kr.status = nil }
    end
  end

  describe 'template_name' do
    it 'returns the template_name fetched from the configuration file of the kubernetes task' do
      assert_equal task.config_file, job.template_name
    end
  end

  describe 'deploy' do
    it 'does nothing' do
      assert_nil job.deploy
    end
  end

  describe 'output' do
    it 'returns an empty string if super didn\'t have anything' do
      assert_equal job.output, ''
    end
  end

  describe 'summary' do
    it 'returns the proper summary' do
      str = "#{user.name} run task #{task.name} #{build.git_sha[0...7]} on #{stage.name}"
      assert_equal str, job.summary
    end
  end

  describe 'summary_for_process' do
    before { JobExecution.expects(:find_by_id).with(job.id).returns(job_execution) }
    before { Time.stubs(:now).returns(now) }
    let(:job_execution) { stub(pid: pid) }
    let(:pid) { 100 }
    let(:now) { job.start_time + 30.seconds }

    it 'returns the proper summary' do
      str = "ProcessID: #{pid} Running task #{task.name}: 30 seconds"

      assert_equal str, job.summary_for_process
    end
  end

  describe 'project' do
    it 'returns the corresponding project' do
      assert_equal stage.project, job.project
    end
  end

  describe 'start_time' do
    it 'returns the created_at value' do
      assert_equal job.created_at, job.start_time
    end
  end

  describe 'finished?' do
    it 'returns false if the status is within the ACTIVE_STATUSES' do
      Kubernetes::Job::ACTIVE_STATUSES.each do |status|
        job.status = status
        assert_not job.finished?, "#{status} is not within the finished statuses"
      end
    end

    it 'returns true if the status is not among the ACTIVE_STATUSES' do
      (Kubernetes::Job::VALID_STATUSES - Kubernetes::Job::ACTIVE_STATUSES).each do |status|
        job.status = status
        assert job.finished?, "'#{status}' is within the finished statuses"
      end
    end
  end

  describe 'active?' do
    it 'returns true if the status is within the ACTIVE_STATUSES' do
      Kubernetes::Job::ACTIVE_STATUSES.each do |status|
        job.status = status
        assert job.active?, "'#{status}' is not within the active statuses"
      end
    end

    it 'returns false if the status is not among the ACTIVE_STATUSES' do
      (Kubernetes::Job::VALID_STATUSES - Kubernetes::Job::ACTIVE_STATUSES).each do |status|
        job.status = status
        assert_not job.active?, "'#{status}' is within the active statuses"
      end
    end
  end

  describe 'statuses' do
    it 'returns true if the status matches the current one' do
      statuses = %w[pending running succeeded cancelling cancelled failed errored]
      statuses.each do |status|
        job.status = status
        assert job.public_send("#{status}?"), "'#{status}' doesn't match the current status"
      end
    end

    it 'returns false if the status doesn\'t match the current one' do
      statuses = %w[pending running succeeded cancelling cancelled failed errored]
      statuses.each do |status|
        current_status = (statuses - [status]).first
        job.status = current_status
        assert_not job.public_send("#{status}?"), "'#{status}' do matches the current status '#{current_status}'"
      end
    end
  end

  describe 'error!' do
    it "sets the status to 'errored' after triggering it" do
      assert_not_equal 'errored', job.status, "The job status shouldn't have been 'errored'"
      job.error!
      assert_equal 'errored', job.status, "The job status wasn't set to errored"
    end
  end

  describe 'success!' do
    it "sets the status to 'success' after triggering it" do
      assert_not_equal 'succeeded', job.status, "The job status shouldn't have been 'succeeded'"
      job.success!
      assert_equal 'succeeded', job.status, "The job status wasn't set to succeeded"
    end
  end

  describe 'fail!' do
    it "sets the status to 'failed' after triggering it" do
      assert_not_equal 'failed', job.status, "The job status shouldn't have been 'failed'"
      job.fail!
      assert_equal 'failed', job.status, "The job status wasn't set to failed"
    end
  end

  describe 'run!' do
    it "sets the status to 'running' after triggering it" do
      assert_not_equal 'running', job.status, "The job status shouldn't have been 'running'"
      job.run!
      assert_equal 'running', job.status, "The job status wasn't set to running"
    end
  end

  describe 'update_output!' do
    before { job.output = '' }
    it 'sets the output to the configured one' do
      job.update_output!('asd')
      assert_equal 'asd', job.output
    end
  end

  describe 'update_git_references!' do
    before { job.commit = '' }
    before { job.tag = '' }
    it 'sets the commit and tag to the configured one' do
      job.update_git_references!(commit: 'a5ca253d7a26e65948d0140869db3f12d56a43f8', tag: 'v1')
      assert_equal 'a5ca253d7a26e65948d0140869db3f12d56a43f8', job.commit
      assert_equal 'v1', job.tag
    end
  end

  describe 'started_by?' do
    let(:admin_user) { users(:admin) }
    it 'returns true if the user started the job' do
      assert job.started_by?(user)
    end

    it 'returns false if the user started the job' do
      assert_not job.started_by?(admin_user)
    end
  end
end

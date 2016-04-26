require_relative '../test_helper'

SingleCov.covered! uncovered: 6

describe JobExecution do
  include GitRepoTestHelper

  let(:repo_dir) { File.join(GitRepository.cached_repos_dir, project.repository_directory) }
  let(:pod1) { deploy_groups(:pod1) }
  let(:pod2) { deploy_groups(:pod2) }
  let(:deploy_group_hack) { DeployGroup.create!(name: ';|sudo make-sandwich /', environment: pod1.environment) }
  let(:project) { Project.create!(name: 'duck', repository_url: repo_temp_dir) }
  let(:stage) { Stage.create!(name: 'stage4', project: project, deploy_groups: [pod1, pod2, deploy_group_hack]) }
  let(:stage_no_groups) { Stage.create!(name: 'stage_no_groups', project: project, deploy_groups: []) }
  let(:user) { User.create!(name: 'test') }
  let(:job) { project.jobs.create!(command: 'cat foo', user: user, project: project) }
  let(:execution) { JobExecution.new('master', job) }
  let(:deploy) { Deploy.create!(stage: stage, job: job, reference: 'master') }

  before do
    Project.any_instance.stubs(:valid_repository_url).returns(true)
    create_repo_with_tags('v1')
    user.name = 'John Doe'
    user.email = 'jdoe@test.com'
    project.repository.clone!(mirror: true)
    job.deploy = deploy
    JobExecution.enabled = true
    JobExecution.clear_registry
  end

  after do
    FileUtils.rm_rf(repo_temp_dir)
    FileUtils.rm_rf(repo_dir)
    project.repository.clean!
    JobExecution.enabled = false
  end

  it "clones the project's repository if it's not already cloned" do
    execution.send(:run!)
    assert File.directory?(repo_dir)
  end

  it 'checks out the specified commit' do
    execute_on_remote_repo <<-SHELL
      git tag foobar
      echo giraffe > foo
      git add foo
      git commit -m "second commit"
    SHELL

    execute_job 'foobar'

    assert_equal 'monkey', last_line_of_output
  end

  it 'checks out the specified remote branch' do
    execute_on_remote_repo <<-SHELL
      git checkout -b armageddon
      echo lion > foo
      git add foo
      git commit -m "branch commit"
      git checkout master
    SHELL

    execute_job 'armageddon'

    assert job.succeeded?
    assert_equal 'lion', last_line_of_output
  end

  it 'records the commit properly when given an annotated tag' do
    execute_on_remote_repo <<-SHELL
      git checkout -b mantis_shrimp
      echo mantis shrimp > foo
      git add foo
      git commit -m "commit"
      git tag -a annotated_tag -m "annotation"
      git checkout master
    SHELL

    branch = File.join(repo_temp_dir, '.git', 'refs', 'heads', 'mantis_shrimp')
    commit = File.read(branch).strip

    execute_job 'annotated_tag'

    assert job.succeeded?
    assert_equal 'mantis shrimp', last_line_of_output
    assert job.commit.present?, "Expected #{job} to record the commit"
    assert_equal commit, job.commit
    assert_includes 'annotated_tag', job.tag
  end

  it "updates the branch to match what's in the remote repository" do
    execute_on_remote_repo <<-SHELL
      git checkout -b safari
      echo tiger > foo
      git add foo
      git commit -m "commit"
      git checkout master
    SHELL

    execute_job 'safari'

    assert_equal 'tiger', last_line_of_output

    execute_on_remote_repo <<-SHELL
      git checkout safari
      echo zebra > foo
      git add foo
      git commit -m "second commit"
      git checkout master
    SHELL

    execute_job 'safari'

    assert_equal 'zebra', last_line_of_output
  end

  it "tests additional exports hook" do
    job.update(command: 'env | sort')

    Samson::Hooks.callback :job_additional_vars do |job|
      { ADDITIONAL_EXPORT: "yes" }
    end

    execute_job
    lines = job.output.split "\n"
    lines.must_include "ADDITIONAL_EXPORT=yes"
  end

  it "exports deploy information as environment variables" do
    job.update(command: 'env | sort')
    execute_job('master', FOO: 'bar')
    lines = job.output.split "\n"
    lines.must_include "DEPLOY_URL=#{deploy.full_url}"
    lines.must_include "DEPLOYER=jdoe@test.com"
    lines.must_include "DEPLOYER_EMAIL=jdoe@test.com"
    lines.must_include "DEPLOYER_NAME=John Doe"
    lines.must_include "REVISION=master"
    lines.must_include "TAG=v1"
    lines.must_include "FOO=bar"
  end

  it 'works without a deploy' do
    job_without_deploy = project.jobs.build(command: 'cat foo', user: user, project: project)
    execution = JobExecution.new('master', job_without_deploy)
    execution.send(:run!)
    # if you like, pretend there's a wont_raise assertion here
    # this is to make sure we don't add a hard dependency on having a deploy
  end

  it 'does not export deploy_group information if no deploy groups present' do
    job.update(command: 'env | sort')
    deploy.stub :stage, stage_no_groups do
      execute_job
      job.output.wont_include "DEPLOY_GROUPS"
    end
  end

  it 'maintains a cache of build artifacts between runs' do
    job.command = 'echo hello > $CACHE_DIR/foo'
    execute_job

    job.command = 'cat $CACHE_DIR/foo'
    execute_job
    assert_equal 'hello', last_line_of_output
  end

  it 'removes the job from the registry' do
    execution = JobExecution.start_job(JobExecution.new('master', job))

    JobExecution.find_by_id(job.id).wont_be_nil

    execution.wait!

    JobExecution.find_by_id(job.id).must_be_nil
  end

  it 'calls subscribers after finishing' do
    called_subscriber = false
    execute_job { called_subscriber = true }
    assert_equal true, called_subscriber
  end

  it 'outputs start / stop events' do
    execution = JobExecution.new('master', job)
    output = execution.output
    execution.send(:run!)

    assert output.include?(:started, '')
    assert output.include?(:finished, '')
  end

  it 'calls subscribers after queued stoppage' do
    called_subscriber = false

    execution = JobExecution.new('master', job)
    execution.on_complete { called_subscriber = true }
    execution.stop!

    assert_equal true, called_subscriber
    assert_equal 'cancelled', job.status
  end

  it 'saves job output before calling subscriber' do
    output = nil
    execute_job { output = job.output }
    assert_equal 'monkey', output.split("\n").last.strip
  end

  it 'errors if job setup fails' do
    execute_job('nope')
    assert_equal 'errored', job.status
  end

  it 'cannot setup project if project is locked' do
    JobExecution.any_instance.stubs(lock_timeout: 0.5) # 2 runs in the loop
    project.repository.expects(:setup!).never
    begin
      MultiLock.send(:try_lock, project.id, 'me')
      execution.send(:run!)
    ensure
      MultiLock.send(:unlock, project.id)
    end
  end

  it 'can access secrets' do
    create_secret "#{project.permalink}/bar"
    job.update(command: "echo '#{"secret://#{project.permalink}/bar"}'")
    execute_job("master")
    assert_equal 'MY-SECRET', last_line_of_output
  end

  describe "kubernetes" do
    before { stage.update_column :kubernetes, true }

    it "does the execution with the kubernetes executor" do
      Kubernetes::DeployExecutor.any_instance.expects(:execute!).returns true
      execute_job("master")
    end
  end

  describe 'when JobExecution is disabled' do
    before do
      JobExecution.enabled = false
    end

    it 'does not add the job to the registry' do
      job_execution = JobExecution.start_job(JobExecution.new('master', job))
      job_execution.wont_be_nil

      JobExecution.find_by_id(job.id).must_equal(job_execution)
      JobExecution.queued?(job.id).must_equal(false)
      JobExecution.active?(job.id).must_equal(false)
    end
  end

  describe "#start!" do
    let(:execution) { JobExecution.new('master', job) }

    it "runs a job" do
      execution.start!
      execution.wait!
      execution.output.to_s.must_include "cat foo"
      job.reload.output.must_include "cat foo"
    end

    it "records exceptions" do
      job.expects(:run!).raises("Oh boy")
      execution.start!
      execution.wait!
      execution.output.to_s.must_include "JobExecution failed: Oh boy"
      job.reload.output.must_include "JobExecution failed: Oh boy"
    end
  end

  describe "#stop!" do
    let(:execution) { JobExecution.new('master', job) }

    it "stops the execution with interrupt" do
      execution.start!
      TerminalExecutor.any_instance.expects(:stop!).with('INT')
      execution.stop!
    end

    it "stops the execution with kill if job has already been interrupted" do
      begin
        old, JobExecution.stop_timeout = JobExecution.stop_timeout, 0
        execution.start!
        TerminalExecutor.any_instance.expects(:stop!).with('INT')
        TerminalExecutor.any_instance.expects(:stop!).with('KILL')
        execution.stop!
      ensure
        JobExecution.stop_timeout = old
      end
    end
  end

  def execute_job(branch = 'master', **options)
    execution = JobExecution.new(branch, job, options)
    execution.on_complete { yield } if block_given?
    execution.send(:run!)
  end

  def last_line_of_output
    job.output.to_s.split("\n").last.strip
  end
end

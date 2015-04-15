require_relative '../test_helper'

describe JobExecution do

  let(:repository_url) { Dir.mktmpdir }
  let(:repo_dir) { File.join(GitRepository.cached_repos_dir, project.repository_directory) }
  let(:project) { Project.create!(name: 'duck', repository_url: repository_url) }
  let(:stage) { Stage.create!(name: 'stage4', project: project) }
  let(:user) { User.create!(name: 'test') }
  let(:job) { project.jobs.create!(command: 'cat foo', user: user, project: project) }
  let(:execution) { JobExecution.new('master', job) }
  let(:deploy) { Deploy.create!(stage: stage, job: job, reference: 'masterCADF') }

  before do
    Project.any_instance.stubs(:valid_repository_url).returns(true)
    execute_on_remote_repo <<-SHELL
      git init
      git config user.email "test@example.com"
      git config user.name "Test User"
      echo monkey > foo
      git add foo
      git commit -m "initial commit"
      git tag v1
    SHELL
    user.name = 'John Doe'
    user.email = 'jdoe@test.com'
    project.repository.clone!(mirror: true)
    JobExecution.enabled = true
  end

  after do
    FileUtils.rm_rf(repository_url)
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

    branch = File.join(repository_url, '.git', 'refs', 'heads', 'mantis_shrimp')
    commit = File.read(branch).strip

    execute_job 'annotated_tag'

    assert_equal 'mantis shrimp', last_line_of_output
    assert job.commit.present?, "Expected #{job} to record the commit"
    assert_includes commit, job.commit
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

  it "exports deploy information as environment variables" do
    job.update(command: 'env')
    execute_job
    lines = job.output.split "\n"
    lines.must_include "DEPLOYER=jdoe@test.com"
    lines.must_include "DEPLOYER_EMAIL=jdoe@test.com"
    lines.must_include "DEPLOYER_NAME=John Doe"
    lines.must_include "REVISION=master"
    lines.must_include "TAG=v1"
  end

  it 'maintains a cache of build artifacts between runs' do
    job.command = 'echo hello > $CACHE_DIR/foo'
    execute_job

    job.command = 'cat $CACHE_DIR/foo'
    execute_job
    assert_equal 'hello', last_line_of_output
  end

  it 'removes the job from the registry' do
    execution = JobExecution.start_job('master', job)

    JobExecution.find_by_id(job.id).wont_be_nil

    execution.wait!

    JobExecution.find_by_id(job.id).must_be_nil
  end

  it 'cannot setup project if project is locked' do
    JobExecution.any_instance.stubs(:lock_timeout => 0.5) # 2 runs in the loop
    project.repository.expects(:setup!).never
    begin
      MultiLock.send(:try_lock, project.id, 'me')
      execution.send(:run!)
    ensure
      MultiLock.send(:unlock, project.id)
    end
  end

  describe 'when JobExecution is disabled' do
    before do
      JobExecution.enabled = false
    end

    it 'does not add the job to the registry' do
      job_execution = JobExecution.start_job('master', job)
      job_execution.wont_be_nil
      JobExecution.find_by_id(job.id).must_be_nil
    end
  end

  def execute_job(branch = 'master')
    execution = JobExecution.new(branch, job)
    execution.send(:run!)
  end

  def execute_on_remote_repo(cmds)
    `exec 2> /dev/null; cd #{repository_url}; #{cmds}`
  end

  def last_line_of_output
    job.output.to_s.split("\n").last.strip
  end
end

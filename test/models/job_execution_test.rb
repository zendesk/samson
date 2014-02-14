require_relative '../test_helper'

describe JobExecution do
  let(:repository_url) { Dir.mktmpdir }
  let(:base_dir) { Dir.mktmpdir }
  let(:project) { Project.create!(name: "duck", repository_url: repository_url) }
  let(:stage) { Stage.create!(name: "stage4", project: project) }
  let(:cached_repo_dir) { "#{base_dir}/cached_repos/#{project.id}" }
  let(:user) { User.create! }
  let(:job) { project.jobs.create!(command: "cat foo", user: user, project: project) }
  let(:execution) { JobExecution.new("master", job) }

  before do
    deploy = Deploy.create!(stage: stage, job: job, reference: "masterCADF")
    JobExecution.enabled = true
    execute_on_remote_repo <<-SHELL
      git init
      git config user.email "test@example.com"
      git config user.name "Test User"
      echo monkey > foo
      git add foo
      git commit -m "initial commit"
    SHELL
  end

  after do
    system("rm -fr #{repository_url}")
    JobExecution.enabled = false
  end

  it "clones the project's repository if it's not already cloned" do
    execution.run!
    repo_dir = File.join(Rails.application.config.pusher.cached_repos_dir, project.id.to_s)

    assert File.directory?(repo_dir)
  end

  it "clones the cached repository into a temporary repository"

  it "checks out the specified commit" do
    execute_on_remote_repo <<-SHELL
      git tag foobar
      echo giraffe > foo
      git add foo
      git commit -m "second commit"
    SHELL

    execute_job "foobar"

    assert_equal "monkey", last_line_of_output
  end

  it "checks out the specified remote branch" do
    execute_on_remote_repo <<-SHELL
      git checkout -b armageddon
      echo lion > foo
      git add foo
      git commit -m "branch commit"
      git checkout master
    SHELL

    execute_job "armageddon"

    assert_equal "lion", last_line_of_output
  end

  it "updates the branch to match what's in the remote repository" do
    execute_on_remote_repo <<-SHELL
      git checkout -b safari
      echo tiger > foo
      git add foo
      git commit -m "commit"
      git checkout master
    SHELL

    execute_job "safari"

    assert_equal "tiger", last_line_of_output

    execute_on_remote_repo <<-SHELL
      git checkout safari
      echo zebra > foo
      git add foo
      git commit -m "second commit"
      git checkout master
    SHELL

    execute_job "safari"

    assert_equal "zebra", last_line_of_output
  end

  it "maintains a cache of build artifacts between runs" do
    job.command = "echo hello > $CACHE_DIR/foo"
    execute_job

    job.command = "cat $CACHE_DIR/foo"
    execute_job
    assert_equal "hello", last_line_of_output
  end

  it "removes the job from the registry" do
    execution = JobExecution.start_job("master", job)

    JobExecution.find_by_job(job).wont_be_nil

    execution.wait!

    JobExecution.find_by_job(job).must_be_nil
  end

  it "runs the commands specified by the job"

  describe "when JobExecution is disabled" do
    before do
      JobExecution.enabled = false
    end

    it "does not add the job to the registry" do
      job_execution = JobExecution.start_job('master', job)
      job_execution.wont_be_nil
      JobExecution.find_by_job(job).must_be_nil
    end
  end

  def execute_job(branch = "master")
    execution = JobExecution.new(branch, job)
    execution.run!
  end

  def execute_on_remote_repo(cmds)
    `exec 2> /dev/null; cd #{repository_url}; #{cmds}`
  end

  def last_line_of_output
    job.output.to_s.split("\n").last.strip
  end
end

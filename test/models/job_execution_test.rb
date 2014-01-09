require 'test_helper'

describe JobExecution do
  let(:repository_url) { Dir.mktmpdir }
  let(:base_dir) { Dir.mktmpdir }
  let(:project) { Project.create!(name: "duck", repository_url: repository_url) }
  let(:cached_repo_dir) { "#{base_dir}/cached_repos/#{project.id}" }
  let(:user) { User.create! }
  let(:job) { project.jobs.create!(command: "echo hello", user: user) }
  let(:execution) { JobExecution.new("master", job, base_dir) }

  before do
    `#{<<-SHELL}`
      cd #{repository_url}
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
  end

  it "clones the project's repository if it's not already cloned" do
    execution.start_and_wait!

    assert File.directory?("#{cached_repo_dir}/.git")
  end

  it "clones the cached repository into a temporary repository"

  it "checks out the specified commit" do
    `#{<<-SHELL}`
      cd #{repository_url}
      git tag foobar
      echo giraffe > foo
      git add foo
      git commit -m "second commit"
    SHELL

    job.command = "cat foo"
    execution = JobExecution.new("foobar", job, base_dir)
    execution.start_and_wait!

    assert_equal "monkey", job.output.to_s.split("\n").last.strip
  end

  it "checks out the specified remote branch" do
    `#{<<-SHELL}`
      exec 2> /dev/null # ignore stderr
      cd #{repository_url}
      git co -b armageddon
      echo lion > foo
      git add foo
      git commit -m "branch commit"
      git checkout master
    SHELL

    job.command = "cat foo"
    execution = JobExecution.new("armageddon", job, base_dir)
    execution.start_and_wait!

    assert_equal "lion", job.output.to_s.split("\n").last.strip
  end

  it "runs the commands specified by the job"
end

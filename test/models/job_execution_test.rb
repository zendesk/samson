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
      git commit --allow-empty -m "initial commit"
    SHELL
  end

  after do
    system("rm -fr #{repository_url}")
  end

  it "clones the project's repository if it's not already cloned" do
    execution.start!
    execution.wait

    assert File.directory?("#{cached_repo_dir}/.git")
  end

  it "clones the cached repository into a temporary repository"
  it "checks out the specified commit"
  it "runs the commands specified by the job"
end

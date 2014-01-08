require 'test_helper'

describe JobExecution do
  let(:project) { Project.create!(name: "duck", repository_url: repository_url) }
  let(:cached_repo_dir) { "#{base_dir}/cached_repos/#{project.id}" }
  let(:user) { User.create! }
  let(:execution) { JobExecution.new(commit, job, base_dir) }

  describe "local project" do
    let(:repository_url) { Dir.mktmpdir }
    let(:base_dir) { Dir.mktmpdir }
    let(:job) { project.jobs.create!(command: "echo hello", user: user) }
    let(:commit) { "master" }

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

    it "runs the commands specified by the job"
  end

  describe "remote project" do
    let(:repository_url) { 'https://github.com/zendesk/curly.git' }
    let(:base_dir) { Dir.mktmpdir }
    let(:job) { project.jobs.create!(command: "git rev-parse HEAD", user: user) }

    let(:output) do
      execution.start_and_wait!
      execution.output.messages.last
    end

    describe "remote SHA" do
      let(:commit) { '431a569987c1318d63dda44797d8792ea7566394' }

      it 'returns sha' do
        output.must_equal(commit)
      end
    end

    describe "remote tag" do
      let(:commit) { 'v0.12.0' }

      it 'returns tag' do
        output.must_equal('431a569987c1318d63dda44797d8792ea7566394')
      end
    end

=begin
TODO: failures

    describe "remote branch" do
      let(:commit) { 'origin/dasch/compiler' }

      it 'returns local branch' do
        output.must_equal('dasch/compiler')
      end
    end

    describe "local-ish remote branch" do
      let(:commit) { 'dasch/compiler' }

      it 'returns local branch' do
        output.must_equal(commit)
      end
    end
=end
  end
end

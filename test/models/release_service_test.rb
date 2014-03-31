require_relative '../test_helper'

class ReleaseServiceTest < ActiveSupport::TestCase
  let(:repository_url) { Dir.mktmpdir }
  let(:project) { Project.create!(name: "duck", repository_url: repository_url) }
  let(:author) { users(:deployer) }
  let(:service) { ReleaseService.new(project) }
  let(:sha) { execute_on_remote_repo("git rev-parse HEAD").strip }

  before do
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

  it "creates a new release" do
    count = Release.count

    service.create_release(commit: sha, author: author)

    assert_equal count + 1, Release.count
  end

  it "creates a git tag on the commit" do
    release = service.create_release(commit: sha, author: author)

    assert_equal sha, execute_on_remote_repo("git rev-parse #{release.version}").strip 
  end

  it "deploys the commit to stages if they're configured to" do
    stage = project.stages.create!(name: "production", deploy_on_release: true)
    release = service.create_release(commit: sha, author: author)

    # Make sure the deploy has taken place.
    JobExecution.all.each(&:wait!)

    assert_equal release.version, stage.deploys.last.reference
  end

  def execute_on_remote_repo(cmds)
    `exec 2> /dev/null; cd #{repository_url}; #{cmds}`.tap do
      raise "command failed" unless $?.success?
    end
  end
end

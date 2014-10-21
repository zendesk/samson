require_relative '../test_helper'

describe ReleaseTagger, :model do
  let(:repository_url) { Dir.mktmpdir }
  let(:project) { Project.create!(name: "duck", repository_url: repository_url) }
  let(:author) { users(:deployer) }
  let(:release_tagger) { ReleaseTagger.new(project) }
  let(:sha) { execute_on_remote_repo("git rev-parse HEAD").strip }
  let(:release) { project.releases.create!(author: author, number: 22, commit: sha) }

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
    FileUtils.rm_rf(repository_url)
    FileUtils.rm_rf(File.join(JobExecution.cached_repos_dir, project.repository_directory))
    JobExecution.enabled = false
  end

  it "creates and pushes a git tag on the commit" do
    release_tagger.tag_release!(release)

    remote_sha = execute_on_remote_repo("git rev-parse #{release.version}").strip
    assert_equal sha, remote_sha
  end

  it "raises InvalidCommit if the commit was not a valid reference" do
    release = project.releases.create!(author: author, number: 12, commit: "nanana")

    assert_raises ReleaseTagger::InvalidCommit do
      release_tagger.tag_release!(release)
    end
  end

  it "raises Error if the tagging failed for any reason" do
    system("rm -fr #{repository_url}")

    assert_raises ReleaseTagger::Error do
      release_tagger.tag_release!(release)
    end
  end

  def execute_on_remote_repo(cmds)
    `exec 2> /dev/null; cd #{repository_url}; #{cmds}`.tap do
      raise "command failed" unless $?.success?
    end
  end
end

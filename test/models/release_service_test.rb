require_relative '../test_helper'

describe ReleaseService, :model do
  let(:project) { projects(:test) }
  let(:author) { users(:deployer) }
  let(:service) { ReleaseService.new(project) }
  let(:commit) { "abcd" }
  let(:release_tagger) { stub("release_tagger") }
  let(:tag_release_called) { [] }

  before do
    ReleaseTagger.stubs(:new).with(project).returns(release_tagger)
    release_tagger.stubs(:tag_release!).capture(tag_release_called)
  end

  it "creates a new release" do
    count = Release.count

    service.create_release(commit: commit, author: author)

    assert_equal count + 1, Release.count
  end

  it "tags the release" do
    release = service.create_release(commit: commit, author: author)
    assert_equal [[release]], tag_release_called
  end

  it "deploys the commit to stages if they're configured to" do
    stage = project.stages.create!(name: "production", deploy_on_release: true)
    release = service.create_release(commit: commit, author: author)

    assert_equal release.version, stage.deploys.first.reference
  end
end

# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Release do
  let(:author) { users(:deployer) }
  let(:project) { projects(:test) }
  let(:release) { releases(:test) }

  describe "create" do
    let(:commit) { "abcd" }

    it "creates a new release" do
      release = project.releases.create!(commit: commit, author: author)
      assert_equal "124", release.number
    end

    describe "when incrementing the release number" do
      let(:release) { project.releases.create!(author: author, commit: "bar") }
      [
        {type: "continuous", previous: "41", next: "42"},
        {type: "major-minor", previous: "4.1", next: "4.2"},
        {type: "semantic", previous: "4.1.1", next: "4.1.2"},
      ].each do |version_type|
        it "correctly increments #{version_type[:type]} versions" do
          release.update_column(:number, version_type[:previous])
          release = project.releases.create!(commit: "foo", author: author)
          assert_equal version_type[:next], release.number
        end
      end
    end

    it 'uses the specified release number' do
      release = project.releases.create!(author: author, commit: "bar", number: "1234")
      assert_equal "1234", release.number
    end

    it 'uses the default release number if build number is nil' do
      project.releases.destroy_all
      release = project.releases.create!(author: author, commit: "bar", number: nil)
      assert_equal "1", release.number
    end

    it 'uses the build number if build number is not given' do
      project.releases.destroy_all
      release = project.releases.create!(author: author, commit: "bar")
      assert_equal "1", release.number
    end

    it "validates invalid numbers" do
      release = project.releases.new(author: author, commit: "bar", number: "1a")
      assert_raises ActiveRecord::RecordInvalid do
        release.save!
      end
    end
  end

  describe "#to_param" do
    it "is the number" do
      release.to_param.must_equal "v123"
    end
  end

  describe ".find_by_param!" do
    it "finds" do
      Release.find_by_param!("v123").must_equal release
    end

    it "does not find unknoqn" do
      assert_raises ActiveRecord::RecordNotFound do
        Release.find_by_param!("123")
      end
    end
  end

  describe "#currently_deploying_stages" do
    let(:stage) { project.stages.create!(name: "One") }
    before { release.update_column(:number, '42') }

    it "returns stages where the release is pending deploy" do
      create_deploy!(reference: "v42", status: "pending")
      assert_equal [stage], release.currently_deploying_stages
    end

    it "returns stages where the release is currently being deployed" do
      create_deploy!(reference: "v42", status: "running")
      assert_equal [stage], release.currently_deploying_stages
    end

    it "returns stages where a deploy of the release is being cancelled" do
      create_deploy!(reference: "v42", status: "cancelling")
      assert_equal [stage], release.currently_deploying_stages
    end

    it "ignores stages where there are no current deploys" do
      create_deploy!(reference: "v42", status: "succeeded")
      assert_equal [], release.currently_deploying_stages
    end

    it "ignores stages where another release is being deployed" do
      create_deploy!(reference: "v666", status: "running")
      assert_equal [], release.currently_deploying_stages
    end

    it "handles deleted author" do
      create_deploy!(reference: "v666", status: "succeeded")
      author.soft_delete!
      release.reload
      assert_equal author.name, release.author.name
    end

    it "handles deleted author" do
      create_deploy!(reference: "v666", status: "succeeded")
      author.destroy!
      release.reload
      assert_equal NullUser.new(0).name, release.author.name
    end

    def create_deploy!(options)
      job = project.jobs.create!(user: author, commit: "x", command: "yes", status: options.fetch(:status))
      stage.deploys.create!(reference: options.fetch(:reference), job: job)
    end
  end

  describe "#changeset" do
    it "returns changeset" do
      release = project.releases.create!(commit: "foo", author: author)
      assert_equal 'abc...foo', release.changeset.commit_range
    end

    it 'returns empty changeset when there is no prior release' do
      assert_equal 'abc...abc', release.changeset.commit_range
      assert_equal [], release.changeset.commits
    end
  end

  describe "#contains_commit?" do
    before { project.stubs(:repository).returns(mock) }

    it "is true if it contains commit" do
      stub_github_api('repos/bar/foo/compare/abc...NEW', status: 'behind')
      assert release.contains_commit?("NEW")
    end

    it "is false if it does not contain commit" do
      stub_github_api('repos/bar/foo/compare/abc...NEW', status: 'ahead')
      refute release.contains_commit?("NEW")
    end

    it "is true if it is the same commit" do
      assert release.contains_commit?(release.commit)
    end

    it "is false on error and reports to airbrake" do
      stub_github_api('repos/bar/foo/compare/abc...NEW', {}, 400)
      Airbrake.expects(:notify)
      refute release.contains_commit?("NEW")
    end

    it "returns false on 404 and does not report to airbrake since it is common" do
      stub_github_api('repos/bar/foo/compare/abc...NEW', {}, 404)
      Airbrake.expects(:notify).never
      refute release.contains_commit?("NEW")
    end
  end
end

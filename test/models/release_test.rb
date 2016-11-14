# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: 4

describe Release do
  describe "create" do
    let(:project) { projects(:test) }
    let(:author) { users(:deployer) }
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

  describe "#currently_deploying_stages" do
    let(:project) { projects(:test) }
    let(:author) { users(:deployer) }
    let(:stage) { project.stages.create!(name: "One") }
    let(:release) do
      release = project.releases.create!(author: author, commit: "xyz")
      release.update_column(:number, 42)
      release
    end

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
    let(:project) { projects(:test) }
    let(:author) { users(:deployer) }

    it "returns changeset" do
      release = project.releases.create!(commit: "foo", author: author)
      assert_equal 'abc...foo', release.changeset.commit_range
    end

    it 'returns empty changeset when there is no prior release' do
      Release.delete_all
      release = project.releases.create!(author: author, commit: "bar")

      assert_equal 'bar...bar', release.changeset.commit_range
      assert_equal [], release.changeset.commits
    end
  end
end

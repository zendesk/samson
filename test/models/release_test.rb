# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: 2

describe Release do
  let(:author) { users(:deployer) }
  let(:project) { projects(:test) }
  let(:release) { releases(:test) }
  let(:commit) { "abcde" * 8 }

  before { GitRepository.any_instance.stubs(:fuzzy_tag_from_ref).returns(nil) }

  describe "create" do
    it "creates a new release" do
      release = project.releases.create!(commit: commit, author: author)
      assert_equal "124", release.number
    end

    describe "when incrementing the release number" do
      [
        {type: "continuous", previous: "41", next: "42"},
        {type: "major-minor", previous: "4.1", next: "4.2"},
        {type: "semantic", previous: "4.1.1", next: "4.1.2"},
      ].each do |version_type|
        it "correctly increments #{version_type[:type]} versions" do
          release.update_column(:number, version_type[:previous])
          release = project.releases.create!(commit: commit, author: author)
          assert_equal version_type[:next], release.number
        end
      end
    end

    it 'uses the specified release number' do
      release = project.releases.create!(author: author, commit: commit, number: "1234")
      assert_equal "1234", release.number
    end

    it 'uses the default release number if build number is nil' do
      project.releases.destroy_all
      release = project.releases.create!(author: author, commit: commit, number: nil)
      assert_equal "1", release.number
    end

    it 'uses the build number if build number is not given' do
      project.releases.destroy_all
      release = project.releases.create!(author: author, commit: commit)
      assert_equal "1", release.number
    end

    it "validates invalid numbers" do
      release = project.releases.new(author: author, commit: commit, number: "1a")
      assert_raises ActiveRecord::RecordInvalid do
        release.save!
      end
    end

    it "converts refs to commits so we later know what exactly was deployed" do
      project.expects(:repo_commit_from_ref).with('master').returns(commit)
      release = project.releases.create!(author: author, commit: 'master')
      release.commit.must_equal commit
    end

    it "fails with unresolvable ref" do
      project.expects(:repo_commit_from_ref).with('master').returns(nil)
      e = assert_raises ActiveRecord::RecordInvalid do
        project.releases.create!(author: author, commit: 'master')
      end
      e.message.must_equal "Validation failed: Commit can only be a full sha"
    end

    it "does not covert blank commits" do
      GitRepository.any_instance.expects(:clone!).never
      GitRepository.any_instance.expects(:commit_from_ref).never
      e = assert_raises ActiveRecord::RecordInvalid do
        project.releases.create!(author: author, commit: '')
      end
      e.message.must_equal "Validation failed: Commit can only be a full sha"
    end

    it "uses the samson version if it is higher than the github version" do
      GitRepository.any_instance.expects(:fuzzy_tag_from_ref).with(commit).returns("v122")
      release = project.releases.create!(author: author, commit: commit)
      release.commit.must_equal commit
      release.number.must_equal "124"
    end

    it "uses the github version if it is exact on the commit" do
      GitRepository.any_instance.expects(:fuzzy_tag_from_ref).with(commit).returns("v125")
      release = project.releases.create!(author: author, commit: commit)
      release.commit.must_equal commit
      release.number.must_equal "125"
    end

    it "uses github version +1 if it is fuzzy on the commit" do
      GitRepository.any_instance.expects(:fuzzy_tag_from_ref).with(commit).returns("v125-123123")
      release = project.releases.create!(author: author, commit: commit)
      release.commit.must_equal commit
      release.number.must_equal "126"
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

    it "does not find impossible" do
      assert_sql_queries 0 do
        assert_raises ActiveRecord::RecordNotFound do
          Release.find_by_param!("123")
        end
      end
    end

    it "does not find unknoqn" do
      assert_sql_queries 1 do
        assert_raises ActiveRecord::RecordNotFound do
          Release.find_by_param!("v124")
        end
      end
    end
  end

  describe "#changeset" do
    before do
      GitRepository.any_instance.stubs(:exact_tag_from_ref).returns("")
    end

    it "returns changeset" do
      release = project.releases.create!(commit: commit, author: author)
      assert_equal "abcdabcdabcdabcdabcdabcdabcdabcdabcdabcd...#{commit}", release.changeset.commit_range
    end

    it 'returns empty changeset when there is no prior release' do
      assert_equal "#{release.commit}...#{release.commit}", release.changeset.commit_range
      assert_equal [], release.changeset.commits
    end
  end

  describe "#contains_commit?" do
    let(:url) { "repos/bar/foo/compare/#{release.commit}...NEW" }

    before { project.stubs(:repository).returns(mock) }

    it "is true if it contains commit" do
      stub_github_api(url, status: 'behind')
      assert release.contains_commit?("NEW")
    end

    it "is true when it is the same commit but not the same refrence (7 char sha or just wrong usage)" do
      stub_github_api(url, status: 'identical')
      assert release.contains_commit?("NEW")
    end

    it "is false if it does not contain commit" do
      stub_github_api(url, status: 'ahead')
      refute release.contains_commit?("NEW")
    end

    it "is true if it is the same commit" do
      assert release.contains_commit?(release.commit)
    end

    it "is false on error and reports to error notifier" do
      stub_github_api(url, {}, 400)
      Samson::ErrorNotifier.expects(:notify)
      refute release.contains_commit?("NEW")
    end

    it "returns false on 404 and does not report to error notifier since it is common" do
      stub_github_api(url, {}, 404)
      Samson::ErrorNotifier.expects(:notify).never
      refute release.contains_commit?("NEW")
    end
  end

  describe "#assign_release_number" do
    it "skips the github version check if no commit is defined" do
      GitRepository.any_instance.expects(:fuzzy_tag_from_ref).never
      release = project.releases.new

      release.assign_release_number
    end
  end
end

# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Build do
  def stub_commit_from_ref(ref, commit)
    stub_request(:get, "https://api.github.com/repos/bar/foo/commits/#{ref}").
      to_return(
        body: {sha: commit}.to_json,
        status: commit ? 200 : 404,
        headers: {"Content-Type" => "application/json"}
      )
  end

  let(:project) { projects(:test) }
  let(:example_sha) { 'cbbf2f9a99b47fc460d422812b6a5adff7dfee951d8fa2e4a98caa0382cfbdbf' }
  let(:repo_digest) { "my-registry.zende.sk/some_project@sha256:#{example_sha}" }
  let(:build) { builds(:staging) }
  let(:current_commit) { "af0798b05e10ac6b8381f85b38ae3973278e71ba" }

  def valid_build(attributes = {})
    Build.new(attributes.reverse_merge(
      project: project,
      git_ref: 'master',
      creator: users(:admin)
    ))
  end

  describe 'validations' do
    before { stub_commit_from_ref("master", current_commit) }

    it 'validates git sha' do
      stub_commit_from_ref(current_commit, current_commit)
      stub_commit_from_ref('0123456789012345678901234567890123456789', nil)
      stub_commit_from_ref('This is a string of 40 characters.......', nil)
      stub_commit_from_ref('abc', nil)
      assert_valid(valid_build(git_ref: nil, git_sha: current_commit))
      refute_valid(valid_build(git_ref: nil, git_sha: '0123456789012345678901234567890123456789')) # sha no in repo
      refute_valid(valid_build(git_ref: nil, git_sha: 'This is a string of 40 characters.......'))
      refute_valid(valid_build(git_ref: nil, git_sha: 'abc'))
    end

    it "is invalid with a ref and an invalid sha" do
      stub_commit_from_ref('abc', current_commit)
      stub_commit_from_ref('a' * 40, nil)
      refute_valid(valid_build(git_ref: 'abc', git_sha: 'a' * 40))
    end

    it "is valid with a ref and an old sha" do
      stub_commit_from_ref('abc', current_commit)
      stub_commit_from_ref('a' * 40, 'b' * 40)
      assert_valid(valid_build(git_ref: 'abc', git_sha: 'a' * 40))
    end

    it "validates git sha uniqueness with dockerfile" do
      stub_commit_from_ref(current_commit, current_commit)
      build.update_column(:git_sha, current_commit)

      # duplicates are allowed
      assert_valid(valid_build(git_ref: nil, git_sha: current_commit))
      assert_valid(valid_build(git_ref: nil, git_sha: current_commit, dockerfile: 'Other'))
      assert_valid(valid_build(git_ref: nil, git_sha: current_commit, dockerfile: nil, external_status: 'pending'))

      # duplicates using the same external url are not allowed
      build.update_column(:external_url, 'http://mybuilds.io/1234')
      refute_valid(valid_build(git_ref: nil, git_sha: current_commit, external_url: 'http://mybuilds.io/1234'))
    end

    it "validates git sha uniqueness with image_name" do
      stub_commit_from_ref(current_commit, current_commit)

      Build.all.each { |b| b.update_column :dockerfile, b.id }
      build.update_columns(git_sha: current_commit, image_name: 'hello', dockerfile: 'Other')
      builds(:v1_tag).update_columns(git_sha: current_commit, image_name: nil)

      base = {git_ref: nil, git_sha: current_commit, external_status: 'pending'}
      assert_valid(valid_build(base))
      assert_valid(valid_build(base.merge(image_name: 'hello'))) # not unique
      assert_valid(valid_build(base.merge(image_name: 'world'))) # unique
      assert_valid(valid_build(base.merge(image_name: '')))

      # duplicates using the same external url are not allowed
      build.update_column(:external_url, 'http://mybuilds.io/1234')
      refute_valid(valid_build(base.merge(image_name: 'hello', external_url: 'http://mybuilds.io/1234')))
    end

    it 'validates git_ref' do
      stub_commit_from_ref(current_commit, current_commit)
      stub_commit_from_ref('some_tag_i_made_up', nil)
      assert_valid(valid_build(git_ref: 'master'))
      refute_valid(Build.new(project: project))
      assert_valid(valid_build(git_ref: current_commit))
      refute_valid(valid_build(git_ref: 'some_tag_i_made_up'))
    end

    it 'validates docker digest' do
      stub_commit_from_ref("a" * 40, current_commit)
      assert_valid(valid_build(docker_repo_digest: repo_digest, git_sha: 'a' * 40))
      assert_valid(valid_build(docker_repo_digest: "", git_sha: 'a' * 40))
      multi_slash = "my-registry.zende.sk/samson/another_project@sha256:#{example_sha}"
      assert_valid(valid_build(docker_repo_digest: multi_slash, git_sha: 'a' * 40))
      assert_valid(valid_build(docker_repo_digest: "ruby@sha256:#{"a" * 64}", git_sha: 'a' * 40))
      refute_valid(valid_build(docker_repo_digest: example_sha, git_sha: 'a' * 40))
      refute_valid(valid_build(docker_repo_digest: 'some random string', git_sha: 'a' * 40))
    end

    it 'is invalid with protocol weird url' do
      refute_valid(valid_build(external_url: 'foo.com'))
      refute_valid(valid_build(external_url: 'ftp://foo.com'))
    end

    it 'is valid with real url' do
      assert_valid(valid_build(external_url: 'http://foo.com'))
      assert_valid(valid_build(external_url: 'https://foo.com'))
    end

    it 'is invalid when docker_repo_digest was given without an exact git_sha' do
      refute_valid(valid_build(docker_repo_digest: repo_digest))
    end

    it 'validates dockerfile exists when build needs to be done by samson' do
      assert_valid(valid_build(dockerfile: 'Dockerfile'))
      refute_valid(valid_build(dockerfile: nil))
      assert_valid(valid_build(dockerfile: nil, external_status: 'pending'))
    end

    describe 'external_status' do
      it 'ignores when not external' do
        build = valid_build
        assert_valid build
        build.external_status.must_be_nil
      end

      it 'is valid with valid status' do
        build = valid_build(external_status: 'running')
        assert_valid build
        build.external_status.must_equal 'running'
      end

      it 'is invalid with invalid status' do
        refute_valid valid_build(external_status: 'sdfsfsfdf')
      end

      it 'is invalid with invalid status on non-external' do
        refute_valid valid_build(external_status: 'sdfsfsfdf')
      end
    end
  end

  describe 'create' do
    let(:project) { projects(:test) }

    it 'increments the build number' do
      stub_commit_from_ref("master", "a" * 40)
      biggest_build_num = project.builds.maximum(:number) || 0
      build = project.builds.create!(git_ref: 'master', creator: users(:admin))
      assert_valid(build)
      assert_equal(biggest_build_num + 1, build.number)
    end
  end

  describe "#url" do
    it "builds a url" do
      build = builds(:staging)
      build.url.must_equal "http://www.test-url.com/projects/foo/builds/#{build.id}"
    end
  end

  describe "#nice_name" do
    it "builds a nice name" do
      build.nice_name.must_equal "Build #{build.id}"
    end

    it "uses the name when avialable" do
      build.name = 'foo'
      build.nice_name.must_equal "foo"
    end
  end

  describe "#commit_url" do
    it "builds a path when the url is unknown" do
      build.project.repository_url = 'git@example.com:foo/bar.git'
      build.commit_url.must_equal "/tree/da39a3ee5e6b4b0d3255bfef95601890afd80709"
    end

    it "builds a full url when host is known" do
      build.commit_url.must_equal "https://github.com/bar/foo/tree/da39a3ee5e6b4b0d3255bfef95601890afd80709"
    end
  end

  describe "#create_docker_job" do
    it "creates a job" do
      build.create_docker_job.class.must_equal Job
    end
  end

  describe "#nil_out_blanks" do
    it "nils out dockerfile so it stays unique" do
      build.update!(image_name: '   ')
      build.image_name.must_be_nil
    end
  end

  describe "#make_dockerfile_and_image_name_not_collide" do
    it "stores nil dockerfile so index does not collide when using image_name for uniqueness" do
      stub_commit_from_ref("master", current_commit)
      build = valid_build(image_name: 'foobar', external_status: 'pending')
      build.save!
      build.dockerfile.must_be_nil
      build.image_name.must_equal 'foobar'
    end
  end

  describe "#active?" do
    it "is not active when not running a job" do
      build.create_docker_job
      assert build.active?
    end

    it "is active when running a job" do
      build.create_docker_job
      assert build.active?
    end

    describe "when external" do
      before { build.external_status = 'pending' }

      it "is active when not finished" do
        assert build.active?
      end

      it "is active when finished" do
        build.docker_repo_digest = 'some-digest'
        refute build.active?
      end

      it "is not active when finished by status" do
        build.external_status = 'failed'
        refute build.active?
      end
    end
  end

  describe "#duration" do
    before do
      job = jobs(:succeeded_test)
      job.created_at = 1.minute.ago
      job.updated_at = job.created_at + 60
      build.docker_build_job = job
      build.created_at = job.created_at
      build.updated_at = job.created_at + 30
    end

    it "is nil without a job" do
      build.docker_build_job = nil
      build.duration.must_be_nil
    end

    it "is job duration" do
      build.duration.must_equal 60.0
    end

    describe "external" do
      before { build.external_status = 'succeeded' }

      it "is external duration" do
        build.duration.must_equal 30.0
      end

      it "is nil when we only got a single external request" do
        build.created_at = build.updated_at
        build.duration.must_be_nil
      end
    end
  end

  describe '#external' do
    it 'returns true if external status is present' do
      build.update_column(:external_status, 'succeeded')

      assert build.external?
    end

    it 'returns true if external url is present' do
      build.update_column(:external_url, 'https://build.com')

      assert build.external?
    end

    it 'returns false if neither external status or url is present' do
      refute build.external?
    end
  end

  describe ".cancel_stalled_builds" do
    before do
      build.update_columns(created_at: 3.hours.ago, external_status: 'running')
    end

    it 'cancels builds that have been running for too long' do
      Build.cancel_stalled_builds

      build.reload.external_status.must_equal 'cancelled'
    end

    it 'does not cancel internal builds' do
      build.update_column(:external_status, nil)

      Build.cancel_stalled_builds

      build.external_status.must_be_nil
    end

    it 'does not cancel finished builds' do
      build.update_column(:external_status, 'succeeded')

      Build.cancel_stalled_builds

      build.external_status.must_equal 'succeeded'
    end

    it 'does not cancel builds that are not stalled' do
      build.update_column(:created_at, 1.hour.ago)

      Build.cancel_stalled_builds

      build.external_status.must_equal 'running'
    end
  end
end

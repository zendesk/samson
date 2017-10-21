# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Build do
  include GitRepoTestHelper

  let(:project) { Project.new(id: 99999, name: 'test_project', repository_url: repo_temp_dir) }
  let(:example_sha) { 'cbbf2f9a99b47fc460d422812b6a5adff7dfee951d8fa2e4a98caa0382cfbdbf' }
  let(:repo_digest) { "my-registry.zende.sk/some_project@sha256:#{example_sha}" }
  let(:build) { builds(:staging) }

  def valid_build(attributes = {})
    Build.new(attributes.reverse_merge(
      project: project,
      git_ref: 'master',
      creator: users(:admin)
    ))
  end

  describe 'validations' do
    let(:repository) { project.repository }
    let(:cached_repo_dir) { File.join(GitRepository.cached_repos_dir, project.repository_directory) }
    let(:git_tag) { 'test_tag' }

    before do
      create_repo_with_tags(git_tag)
    end

    after do
      FileUtils.rm_rf(repo_temp_dir)
      FileUtils.rm_rf(repository.repo_cache_dir)
      FileUtils.rm_rf(cached_repo_dir)
    end

    it 'validates git sha' do
      Dir.chdir(repo_temp_dir) do
        assert_valid(valid_build(git_ref: nil, git_sha: current_commit))
        refute_valid(valid_build(git_ref: nil, git_sha: '0123456789012345678901234567890123456789')) # sha no in repo
        refute_valid(valid_build(git_ref: nil, git_sha: 'This is a string of 40 characters.......'))
        refute_valid(valid_build(git_ref: nil, git_sha: 'abc'))
      end
    end

    it "validates git sha uniqueness with dockerfile" do
      Dir.chdir(repo_temp_dir) do
        build.update_column(:git_sha, current_commit)
        refute_valid(valid_build(git_ref: nil, git_sha: current_commit)) # not unique
        assert_valid(valid_build(git_ref: nil, git_sha: current_commit, dockerfile: 'Other'))
        assert_valid(valid_build(git_ref: nil, git_sha: current_commit, dockerfile: nil))
      end
    end

    it "validates git sha uniqueness with image_name" do
      Dir.chdir(repo_temp_dir) do
        Build.all.each { |b| b.update_column :dockerfile, b.id }
        build.update_columns(git_sha: current_commit, image_name: 'hello', dockerfile: 'Other')
        builds(:v1_tag).update_columns(git_sha: current_commit, image_name: nil)

        refute_valid(valid_build(git_ref: nil, git_sha: current_commit, image_name: 'hello')) # not unique
        assert_valid(valid_build(git_ref: nil, git_sha: current_commit, image_name: 'world'))
        assert_valid(valid_build(git_ref: nil, git_sha: current_commit, image_name: ''))
        assert_valid(valid_build(git_ref: nil, git_sha: current_commit, image_name: nil))
      end
    end

    it 'validates image id' do
      assert_valid(valid_build(docker_image_id: example_sha))
      assert_valid(valid_build(docker_image_id: "sha256:#{example_sha}"))
      refute_valid(valid_build(docker_image_id: 'This is a string of 64 characters...............................'))
      refute_valid(valid_build(docker_image_id: 'abc'))
    end

    it 'validates git_ref' do
      assert_valid(valid_build(git_ref: 'master'))
      assert_valid(valid_build(git_ref: git_tag))
      refute_valid(Build.new(project: project))
      Dir.chdir(repo_temp_dir) do
        assert_valid(valid_build(git_ref: current_commit))
      end
      refute_valid(valid_build(git_ref: 'some_tag_i_made_up'))
    end

    it 'validates docker digest' do
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
  end

  describe 'create' do
    let(:project) { projects(:test) }

    before do
      create_repo_without_tags
      project.repository_url = repo_temp_dir
    end

    it 'increments the build number' do
      biggest_build_num = project.builds.maximum(:number) || 0
      build = project.builds.create!(git_ref: 'master', creator: users(:admin))
      assert_valid(build)
      assert_equal(biggest_build_num + 1, build.number)
    end
  end

  describe '#docker_image=' do
    let(:build) { valid_build }
    let(:docker_image_id) { '2d2b0b3204b0166435c3d96d0b27d0ad2083e5e040192632c58eeb9491d6bfaa' }
    let(:docker_image_json) do
      {
        'Id' => docker_image_id
      }
    end
    let(:mock_docker_image) { stub(json: docker_image_json) }

    it 'updates the docker_image_id' do
      build.docker_image = mock_docker_image
      assert_equal(docker_image_id, build.docker_image_id)
      assert_equal(mock_docker_image, build.docker_image)
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
      build.commit_url.must_equal "/tree/da39a3ee5e6b4b0d3255bfef95601890afd80709"
    end

    it "builds a full url when host is known" do
      build.project.repository_url = 'git@github.com:foo/bar.git'
      build.commit_url.must_equal "https://github.com/foo/bar/tree/da39a3ee5e6b4b0d3255bfef95601890afd80709"
    end
  end

  describe "#docker_status" do
    it "is the build status" do
      build.docker_build_job = Job.new(status: 'foo')
      build.docker_status.must_equal "foo"
    end

    it "is not built when there is no build" do
      build.docker_status.must_equal "not built"
    end

    it "is built externally when digest exists without job" do
      build.docker_repo_digest = 'foo'
      build.docker_status.must_equal "built externally"
    end
  end

  describe "#create_docker_job" do
    it "creates a job" do
      build.create_docker_job.class.must_equal Job
    end
  end

  describe "#nil_out_blanks" do
    it "nils out dockerfile so it stays unique" do
      build.update_attributes!(image_name: '   ')
      build.image_name.must_be_nil
    end
  end

  describe "#make_dockerfile_and_image_name_not_collide" do
    it "stores nil dockerfile so index does not collide when using image_name for uniqueness" do
      GitRepository.any_instance.expects(:commit_from_ref).returns('a' * 40)
      build = valid_build(image_name: 'foobar')
      build.save!
      build.dockerfile.must_be_nil
      build.image_name.must_equal 'foobar'
    end
  end
end

# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered!

describe Kubernetes::BuildFinder do
  def setup_using_previous_builds
    previous = deploys(:failed_staging_test)
    previous.update_column(:id, job.deploy.id - 1) # make previous_deploy work
    previous_sha = 'something-else'
    kubernetes_releases(:test_release).update_columns(deploy_id: previous.id, git_sha: previous_sha) # previous deploy
    build.update_columns(docker_repo_digest: 'ababababab', git_sha: previous_sha) # make build succeeded
    job.deploy.update_column(:kubernetes_reuse_build, true)
  end

  let(:output) { StringIO.new }
  let(:out) { output.string }
  let(:build) { builds(:docker_build) }
  let(:job) { jobs(:succeeded_test) }
  let(:images) { nil }
  let(:finder) { Kubernetes::BuildFinder.new(output, job, 'master', images: images) }

  before do
    build.update_column(:docker_repo_digest, nil) # build is needed
    job.update_column(:commit, build.git_sha) # this is normally done by JobExecution
    GitRepository.any_instance.stubs(:file_content).with('Dockerfile', job.commit).returns "FROM all"
  end

  describe "#ensure_successful_builds" do
    let(:execute) { finder.ensure_successful_builds.presence }

    it "fails when the build is not built" do
      e = assert_raises(Samson::Hooks::UserError) { execute }
      e.message.must_equal "Build #{build.url} was created but never ran, run it manually."
      out.wont_include "Creating Build"
    end

    it "succeeds without a build when there is no Dockerfile" do
      Build.delete_all
      GitRepository.any_instance.expects(:file_content).with('Dockerfile', job.commit).returns nil

      refute_difference 'Build.count' do
        refute execute # no build found or created
        out.must_include "Not creating build"
      end
    end

    it "fails to build when custom dockerfile is missing" do
      Build.delete_all
      job.project.update_column :dockerfiles, 'Foobarfile'
      GitRepository.any_instance.expects(:file_content).with('Foobarfile', job.commit).returns nil

      refute_difference 'Build.count' do
        e = assert_raises(Samson::Hooks::UserError) { execute }
        e.message.must_include "Could not create build for Foobarfile"
      end
    end

    it "waits when build is running" do
      build.create_docker_job.update_column(:status, 'running')
      build.save!

      job = build.docker_build_job
      job.class.any_instance.expects(:reload).with do
        # inside wait loop ... pretend the build worked
        job.status = 'succeeded'
        build.update_column(:docker_repo_digest, 'somet-digest')
        true
      end.returns job

      assert execute

      out.must_include "Waiting for Build #{build.url} to finish."
    end

    it "fails when build job failed" do
      build.create_docker_job.update_column(:status, 'cancelled')
      build.save!
      e = assert_raises Samson::Hooks::UserError do
        execute
      end
      e.message.must_equal "Build #{build.url} is cancelled, rerun it manually."
      out.wont_include "Creating Build"
    end

    describe "when build needs to be created" do
      before do
        build.update_column(:git_sha, 'something-else')
        Build.any_instance.stubs(:validate_git_reference)
      end

      it "retries finding when build is created through parallel execution of build" do
        job.project.docker_release_branch = 'master' # indicates that there will be a build kicked off on merge
        finder.expects(:wait_for_parallel_build_creation).with do
          build.update_column(:git_sha, job.commit)
          build.update_column(:docker_repo_digest, 'somet-digest') # a bit misleading since it should be running
        end
        DockerBuilderService.any_instance.expects(:run).never
        assert execute
        out.must_include "Build #{build.url} is looking good!"
      end

      it "succeeds when the build works" do
        DockerBuilderService.any_instance.expects(:run).with do
          Build.last.create_docker_job.update_column(:status, 'succeeded')
          Build.last.update_column(:docker_repo_digest, 'some-sha')
          true
        end
        assert execute
        out.must_include "Creating build for Dockerfile."
        out.must_include "Build #{Build.last.url} is looking good"
      end

      it "reuses build when told to do so" do
        setup_using_previous_builds

        DockerBuilderService.any_instance.expects(:run).never

        assert execute
        out.must_include "Build #{build.url} is looking good"
      end

      it "fails when the build fails" do
        DockerBuilderService.any_instance.expects(:run).with do
          Build.any_instance.expects(:docker_build_job).at_least_once.returns Job.new(status: 'cancelled')
          true
        end
        e = assert_raises Samson::Hooks::UserError do
          execute
        end
        e.message.must_equal "Build #{Build.last.url} is cancelled, rerun it manually."
        out.must_include "Creating build for Dockerfile."
      end

      it "stops when deploy is cancelled by user" do
        finder.cancelled!
        DockerBuilderService.any_instance.expects(:run).returns(true)
        execute
        out.scan(/.*build.*/).must_equal ["Creating build for Dockerfile."] # not waiting for build
      end
    end

    describe "when finding builds via image_name" do
      let(:images) { ["foo.com/foo/bar:latest"] }

      before do
        build.update_columns(image_name: 'bar', docker_repo_digest: "some-digest")
      end

      it "finds the matching build" do
        execute.must_equal [build]
      end

      it "does not find for different sha" do
        build.update_column(:git_sha, 'other')
        e = assert_raises(Samson::Hooks::UserError) { execute }
        e.message.must_include(
          "Did not find build for 1a6f551a2ffa6d88e15eef5461384da0bfb1c194 and image_name bar"
        )
      end

      it "finds accross projects" do
        Build.any_instance.expects(:url).returns("foo") # bogus project not found so url building fails
        build.update_column(:project_id, 123)
        execute.must_equal [build]
      end

      it "can reuse previous build" do
        setup_using_previous_builds
        execute.must_equal [build]
      end
    end
  end

  describe "#wait_for_parallel_build_creation" do
    it "sleeps ... test to get coverage" do
      finder.expects(:sleep)
      finder.send(:wait_for_parallel_build_creation)
    end

    it "does not sleep when already executed" do
      finder.expects(:sleep)
      2.times { finder.send(:wait_for_parallel_build_creation) }
    end
  end
end

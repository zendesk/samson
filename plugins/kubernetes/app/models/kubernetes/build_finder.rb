# frozen_string_literal: true
# makes sure all builds that are needed for a kubernetes release are successfully built
# (needed builds are determined by projects `dockerfiles` column)
#
# Ideally it would come from what `template_filler.rb` needs, but it wants know about builds to render.
#
# Special cases:
# - when no Dockerfile is in the repo and it is the only requested dockerfile (column default value), return no builds
# - if a build is not found, but the project has as `docker_release_branch` we wait a few seconds and retry
# - builds can be reused from the previous release if the deployer requested it
# - if the deploy is cancelled we finish up asap
# - we find builds accross all projects so multiple projects can share them
module Kubernetes
  class BuildFinder
    TICK = 2.seconds

    def initialize(output, job, reference, images:)
      @output = output
      @job = job
      @reference = reference
      @cancelled = false
      @waited = false
      @images = images
    end

    # deploy was cancelled, so finish up as fast as possible
    def cancelled!
      @cancelled = true
    end

    def ensure_successful_builds
      builds =
        if @images
          find_build_by_image_name(try: true) || begin
            # need some sleeping to wait for callbacks to arrive from external builders
            # since samson and the image building can be triggered at the same time
            sleep 5
            find_build_by_image_name(try: false)
          end
        else
          find_or_create_builds_by_dockerfile
        end

      builds.compact.each do |build|
        wait_for_build(build)
        ensure_build_is_successful(build) unless @cancelled
      end
    end

    def find_or_create_builds_by_dockerfile
      requested = @job.project.dockerfile_list
      requested.map do |dockerfile|
        find_build(dockerfile) || create_build(dockerfile)
      end
    end

    # Finds build by comparing their name (foo.com/bar/baz -> baz) to pre-build images image_name column
    def find_build_by_image_name(try:)
      possible_builds = reused_builds + Build.where(git_sha: @job.commit)
      @images.map do |image|
        self.class.detect_build_by_image_name!(possible_builds, image, try: try) ||
          return # rubocop:disable Lint/NonLocalExitFromIterator
      end
    end

    def self.detect_build_by_image_name!(builds, image, try:)
      image_name = image.split('/').last.split(/[:@]/, 2).first
      builds.detect { |b| b.image_name == image_name } || begin
        if try
          nil
        else
          raise(
            Samson::Hooks::UserError,
            "Did not find build for image_name #{image_name} (from #{image}).\n" \
            "Found image_names #{builds.map(&:image_name).uniq.join(", ")}."
          )
        end
      end
    end

    private

    def find_build(dockerfile)
      find_build_with_retry(dockerfile) ||
        reused_builds.detect { |b| b.dockerfile == dockerfile }
    end

    def reused_builds
      (
        @job.deploy.kubernetes_reuse_build &&
        @job.deploy.previous_deploy&.kubernetes_release&.builds
      ) || []
    end

    def find_build_with_retry(dockerfile)
      build = find_build_without_retry(dockerfile)
      return build if build || @job.project.docker_release_branch.blank?
      wait_for_parallel_build_creation
      find_build_without_retry(dockerfile)
    end

    def find_build_without_retry(dockerfile)
      Build.where(git_sha: @job.commit, dockerfile: dockerfile).first
    end

    # we only wait once no matter how many builds are missing since build creation is fast
    def wait_for_parallel_build_creation
      return if @waited
      sleep 5
      @waited = true
    end

    def create_build(dockerfile)
      name = "build for #{dockerfile}"

      if @job.project.repository.file_content(dockerfile, @job.commit)
        @output.puts("Creating #{name}.")
        build = Build.create!(
          git_sha: @job.commit,
          git_ref: @reference,
          creator: @job.user,
          project: @job.project,
          dockerfile: dockerfile,
          name: "Autobuild for Deploy ##{@job.deploy.id}"
        )
        DockerBuilderService.new(build).run(push: true)
        build
      elsif dockerfile == "Dockerfile"
        @output.puts("Not creating #{name} since is is not in the repository.")
        nil
      else
        raise(
          Samson::Hooks::UserError,
          "Could not create #{name}, since #{dockerfile} does not exist in the repository."
        )
      end
    end

    def wait_for_build(build)
      # We reload the build object from the DB each time we check this, because we want
      # to know if our instance is stale. But we don't want to keeping calling
      # build.reload, because that may mutate the object that's being used in another
      # thread.
      return unless Build.find(build.id).active?

      @output.puts("Waiting for Build #{build.url} to finish.")
      loop do
        break if @cancelled
        sleep TICK
        break unless Build.find(build.id).active?
      end
    ensure
      # We can now safely reload the build object, because it is no longer actively running
      build.reload
    end

    def ensure_build_is_successful(build)
      if build.docker_repo_digest
        @output.puts("Build #{build.url} is looking good!")
      elsif build_job = build.docker_build_job
        raise Samson::Hooks::UserError, "Build #{build.url} is #{build_job.status}, rerun it."
      else
        raise Samson::Hooks::UserError, "Build #{build.url} was created but never ran, run it."
      end
    end
  end
end

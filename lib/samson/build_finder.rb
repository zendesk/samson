# frozen_string_literal: true
# makes sure all builds that are needed for a deploy are successfully built
# (needed builds are determined by projects `dockerfiles` column)
#
# FIXME: Ideally it would come from what `template_filler.rb` needs, but it wants know about builds to render.
#
# Special cases:
# - when no Dockerfile is in the repo and it is the only requested dockerfile (column default value), return no builds
# - if a build is not found, but the project has as `docker_release_branch` we wait a few seconds and retry
# - builds can be reused from the previous release if the deployer requested it
# - if the deploy is cancelled we finish up asap
# - we find builds across all projects so multiple projects can share them
module Samson
  class BuildFinder
    TICK = 2.seconds

    def initialize(output, job, reference, images: nil)
      @output = output
      @job = job
      @reference = reference
      @cancelled = false
      @images = images
    end

    # deploy was cancelled, so finish up as fast as possible
    def cancelled!
      @cancelled = true
    end

    def ensure_successful_builds
      builds =
        if @images
          wait_for_build_creation do |last_try|
            find_build_by_image_name(fail: last_try)
          end
        else
          find_or_create_builds_by_dockerfile
        end

      builds.compact.each do |build|
        wait_for_build_completion(build)
        ensure_build_is_successful(build) unless @cancelled
      end
    end

    def find_or_create_builds_by_dockerfile
      requested = @job.project.dockerfile_list
      requested.map do |dockerfile|
        find_build(dockerfile) ||
          (!@job.project.docker_image_building_disabled? && create_build(dockerfile)) ||
          nil # need nil and not false
      end
    end

    # Finds build by comparing their name (foo.com/bar/baz -> baz) to pre-build images image_name column
    def find_build_by_image_name(fail:)
      possible_builds = reused_builds + Build.where(git_sha: @job.commit)
      @images.map do |image|
        self.class.detect_build_by_image_name!(possible_builds, image, fail: fail) || break
      end
    end

    def self.detect_build_by_image_name!(builds, image, fail:)
      image_name = image.split('/').last.split(/[:@]/, 2).first
      builds.detect { |b| b.image_name == image_name } || (
        if fail
          raise(
            Samson::Hooks::UserError,
            "Did not find build for image_name #{image_name} (from #{image}).\n" \
            "Found image_names #{builds.map(&:image_name).uniq.join(", ")}."
          )
        end
      )
    end

    private

    def find_build(dockerfile)
      wait_for_build_creation { Build.where(git_sha: @job.commit, dockerfile: dockerfile).first } ||
        reused_builds.detect { |b| b.dockerfile == dockerfile }
    end

    def reused_builds
      (
        defined?(SamsonKubernetes) &&
        @job.deploy.kubernetes_reuse_build &&
        @job.deploy.previous_deploy&.kubernetes_release&.builds
      ) || []
    end

    # we only wait once no matter how many builds are missing since build creation is fast
    def wait_for_build_creation
      interval = 5
      @wait_time ||= max_build_wait_time

      loop do
        @wait_time -= interval
        last_try = @wait_time < 0

        build = yield last_try
        return build if build

        break if last_try || @cancelled
        sleep interval
      end
    end

    def max_build_wait_time
      if @job.project.docker_image_building_disabled?
        Integer(ENV['KUBERNETES_EXTERNAL_BUILD_WAIT'] || ENV['EXTERNAL_BUILD_WAIT'] || '5')
      elsif @job.project.docker_release_branch.present?
        5 # wait a little to avoid duplicate builds on release branch callback
      else
        0
      end
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
        DockerBuilderService.new(Build.find(build.id)).run # .find to not update/reload the same object
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

    def wait_for_build_completion(build)
      return unless build.reload.active?

      @output.puts("Waiting for Build #{build.url} to finish.")
      loop do
        break if @cancelled
        sleep TICK
        break unless build.reload.active?
      end
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

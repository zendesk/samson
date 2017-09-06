# frozen_string_literal: true
# makes sure all builds that are needed for a kubernetes release are successfully built
module Kubernetes
  class BuildFinder
    TICK = 2.seconds

    def initialize(output, job, reference)
      @output = output
      @job = job
      @reference = reference
      @cancelled = false
    end

    # deploy was cancelled, so finish up as fast as possible
    def cancelled!
      @cancelled = true
    end

    def ensure_successful_builds
      return unless builds = (find_builds || create_builds)
      builds.each do |build|
        wait_for_build(build)
        ensure_build_is_successful(build) unless @cancelled
      end
    end

    private

    def find_builds
      find_builds_with_retry.presence ||
        (@job.deploy.kubernetes_reuse_build && @job.deploy.previous_deploy&.kubernetes_release&.builds)
    end

    def find_builds_with_retry
      builds = Build.where(git_sha: @job.commit).all
      all_builds_found = (@job.project.dockerfile_list.sort - builds.map(&:dockerfile)).empty?
      return builds if all_builds_found || !@job.project.docker_release_branch.present?
      wait_for_parallel_build_creation
      Build.where(git_sha: @job.commit).all
    end

    # stub anchor for tests
    def wait_for_parallel_build_creation
      sleep 5
    end

    def create_builds
      if @job.project.docker_image_building_disabled?
        raise(
          Samson::Hooks::UserError,
          "Not creating a Build for #{@job.commit} since build creation is disabled, use the api to create builds."
        )
      end

      # NOTE: ideally check for all builds the template will use
      dockerfiles = @job.project.dockerfile_list
      if dockerfiles.all? { |df| @job.project.repository.file_content(df, @job.commit) }
        @output.puts("Creating builds for #{@job.commit}.")
        dockerfiles.map do |dockerfile|
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
        end
      else
        @output.puts("Not creating builds for #{@job.commit} since it does not have #{dockerfiles.join(", ")}.")
        false
      end
    end

    def wait_for_build(build)
      if !build.docker_repo_digest && build.docker_build_job&.active?
        @output.puts("Waiting for Build #{build.url} to finish.")
        loop do
          break if @cancelled
          sleep TICK
          break if build.docker_build_job.reload.finished?
        end
      end
      build.reload
    end

    def ensure_build_is_successful(build)
      if build.docker_repo_digest
        @output.puts("Build #{build.url} is looking good!")
      elsif build_job = build.docker_build_job
        raise Samson::Hooks::UserError, "Build #{build.url} is #{build_job.status}, rerun it manually."
      else
        raise Samson::Hooks::UserError, "Build #{build.url} was created but never ran, run it manually."
      end
    end
  end
end

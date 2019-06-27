# frozen_string_literal: true

class DockerBuilderService
  extend ::Samson::PerformanceTracer::Tracers

  def initialize(build)
    @build = build
  end

  def run(tag_as_latest: false)
    return if same_build_in_progress?

    @build.docker_build_job&.destroy # if there's an old build job, delete it
    @build.docker_tag = @build.name&.parameterize.presence || 'latest'
    @build.started_at = Time.now
    @build.docker_repo_digest = nil

    job = @build.create_docker_job
    @build.save!

    @execution = JobExecution.new(@build.git_sha, job) do |_, tmp_dir|
      if @build.docker_repo_digest = build_image(tmp_dir, tag_as_latest: tag_as_latest)
        @build.save!
        true
      else
        @execution.output.puts("Docker build failed (image id not found in response)")
        false
      end
    end

    @build.project.repository.executor = @execution.executor

    @execution.on_finish do
      @build.update_column(:finished_at, Time.now)
      Samson::Hooks.fire(:after_docker_build, @build)
    end

    JobQueue.perform_later @execution
  end

  private

  # In development, memcache can be down and we don't want that to stop builds
  # Note: we need raw: true because of https://github.com/rails/rails/pull/34026
  def same_build_in_progress?
    !Rails.env.development? &&
      !Rails.cache.write("build-service-#{@build.id}", true, unless_exist: true, expires_in: 10.seconds, raw: true)
  end

  def execute_build_command(tmp_dir, command)
    return unless command
    commands = @execution.base_commands(tmp_dir) + command.command.split(/\r?\n|\r/)
    unless @execution.executor.execute(*commands)
      raise Samson::Hooks::UserError, "Error running build command"
    end
  end

  def before_docker_build(tmp_dir)
    Samson::Hooks.fire(:before_docker_repository_usage, @build)
    Samson::Hooks.fire(:before_docker_build, tmp_dir, @build, @execution.output)
    execute_build_command(tmp_dir, @build.project.build_command)
  end
  add_tracer :before_docker_build

  def build_image(tmp_dir, tag_as_latest:)
    File.write("#{tmp_dir}/REVISION", @build.git_sha)

    before_docker_build(tmp_dir)

    cache = @build.project.builds.
      where.not(docker_repo_digest: nil).
      where(dockerfile: @build.dockerfile).
      last&.docker_repo_digest

    builder = if defined?(SamsonGcloud::ImageBuilder) && @build.project.build_with_gcb
      SamsonGcloud::ImageBuilder
    else
      ImageBuilder
    end

    builder.build_image(
      tmp_dir, @build, @execution.executor, tag_as_latest: tag_as_latest, cache_from: cache
    )
  end
  add_tracer :build_image
end

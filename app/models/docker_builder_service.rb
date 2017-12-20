# frozen_string_literal: true
require 'docker'

class DockerBuilderService
  DIGEST_SHA_REGEX = /Digest:.*(sha256:[0-9a-f]{64})/i
  DOCKER_REPO_REGEX = /^BUILD DIGEST: (.*@sha256:[0-9a-f]{64})/i
  include ::NewRelic::Agent::MethodTracer

  attr_reader :build, :execution, :output

  def initialize(build)
    @build = build
    @output = OutputBuffer.new
  end

  def run(push: false, tag_as_latest: false)
    return unless Rails.cache.write("build-service-#{build.id}", true, unless_exist: true, expires_in: 10.seconds)
    build.docker_build_job&.destroy # if there's an old build job, delete it
    build.docker_tag = build.name&.parameterize.presence || 'latest'
    build.started_at = Time.now
    build.docker_repo_digest = nil

    job = build.create_docker_job
    build.save!

    @execution = JobExecution.new(build.git_sha, job, output: @output) do |_, tmp_dir|
      if build_image(tmp_dir, tag_as_latest: tag_as_latest)
        ret = true
        unless build.docker_repo_digest
          ret = push_image(tag_as_latest: tag_as_latest) if push
          unless ENV["DOCKER_KEEP_BUILT_IMGS"] == "1"
            @output.puts("### Deleting local docker image")
            build.docker_image.remove(force: true)
          end
        end
        build.save!
        ret
      else
        output.puts("Docker build failed (image id not found in response)")
        false
      end
    end

    project.repository.executor = @execution.executor

    @execution.on_finish do
      build.update_column(:finished_at, Time.now)
      Samson::Hooks.fire(:after_docker_build, build)
    end

    JobQueue.perform_later(@execution)
  end

  private

  def execute_build_command(tmp_dir, command)
    return unless command
    commands = @execution.base_commands(tmp_dir) + command.command.split(/\r?\n|\r/)
    unless @execution.executor.execute(*commands)
      raise Samson::Hooks::UserError, "Error running build command"
    end
  end

  def before_docker_build(tmp_dir)
    Samson::Hooks.fire(:before_docker_repository_usage, build)
    Samson::Hooks.fire(:before_docker_build, tmp_dir, build, @output)
    execute_build_command(tmp_dir, build.project.build_command)
  end
  add_method_tracer :before_docker_build

  def build_image(tmp_dir, tag_as_latest:)
    File.write("#{tmp_dir}/REVISION", build.git_sha)

    before_docker_build(tmp_dir)

    cache = build.project.builds.
      where.not(docker_repo_digest: nil).
      where(dockerfile: build.dockerfile).
      last&.docker_repo_digest

    if defined?(SamsonGcloud::ImageBuilder) && build.project.build_with_gcb
      # we do not push after this since GCR handles that
      build.docker_repo_digest = SamsonGcloud::ImageBuilder.build_image(
        build, tmp_dir, @execution.executor, tag_as_latest: tag_as_latest, cache_from: cache
      )
    else
      build.docker_image = ImageBuilder.build_image(
        tmp_dir, @execution.executor, dockerfile: build.dockerfile, cache_from: cache
      )
    end
  end
  add_method_tracer :build_image

  def push_image(tag_as_latest: false)
    tag = build.docker_tag
    tag_is_latest = (tag == 'latest')

    unless build.docker_repo_digest = push_image_to_registries(tag: tag, override_tag: tag_is_latest)
      raise Docker::Error::DockerError, "Unable to get repo digest"
    end

    if tag_as_latest && !tag_is_latest
      push_image_to_registries tag: 'latest', override_tag: true
    end
    true
  rescue Docker::Error::DockerError => e
    @output.puts("Docker push failed: #{e.message}\n")
    nil
  end
  add_method_tracer :push_image

  # TODO: move to the image_builder so both have the same interface
  def push_image_to_registries(tag:, override_tag: false)
    digest = nil

    DockerRegistry.all.each_with_index do |registry, i|
      primary = i.zero?
      repo = project.docker_repo(registry, build.dockerfile)

      if override_tag
        @output.puts("### Tagging and pushing Docker image to #{repo}:#{tag}")
      else
        @output.puts("### Pushing Docker image to #{repo} without tag")
      end

      ImageBuilder.local_docker_login do |login_commands|
        full_tag = "#{repo}:#{tag}"

        @execution.executor.quiet do
          return nil unless @execution.executor.execute(
            *login_commands,
            @execution.executor.verbose_command("docker tag #{build.docker_image.id} #{full_tag.shellescape}"),
            @execution.executor.verbose_command("docker push #{full_tag.shellescape}")
          )
        end

        if primary
          # cache-from also produced digest lines, so we need to be careful
          last = @execution.executor.output.to_s.split("\n").last.to_s
          return nil unless sha = last[DIGEST_SHA_REGEX, 1]
          digest = "#{repo}@#{sha}"
        end
      end
    end

    digest
  end

  def project
    @build.project
  end
end

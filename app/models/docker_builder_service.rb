# frozen_string_literal: true
require 'docker'

class DockerBuilderService
  DIGEST_SHA_REGEX = /Digest:.*(sha256:[0-9a-f]+)/i
  DOCKER_REPO_REGEX = /^BUILD DIGEST: (.*@sha256:[0-9a-f]+)/i
  include ::NewRelic::Agent::MethodTracer

  attr_reader :build, :execution

  def self.build_docker_image(dir, docker_options, output)
    output.puts("### Creating tarfile for Docker build")
    tarfile = create_docker_tarfile(dir)

    output.puts("### Running Docker build")
    # our image can depend on other images in the registry ... only first registry supported atm
    credentials_to_pull = registry_credentials(DockerRegistry.first)

    docker_image =
      Docker::Image.build_from_tar(tarfile, docker_options, Docker.connection, credentials_to_pull) do |chunk|
        output.write_docker_chunk(chunk)
      end
    output.puts('### Docker build complete')

    docker_image
  ensure
    if tarfile
      tarfile.close
      FileUtils.rm(tarfile.path, force: true)
    end
  end

  def self.registry_credentials(registry)
    return unless registry.present?
    {
      username: registry.username,
      password: registry.password,
      email: ENV['DOCKER_REGISTRY_EMAIL'],
      serveraddress: registry.host
    }
  end

  def initialize(build)
    @build = build
  end

  def run!(push: false, tag_as_latest: false)
    build.docker_build_job&.destroy # if there's an old build job, delete it
    build.docker_tag = build.label.try(:parameterize).presence || 'latest'
    build.started_at = Time.now

    job = build.create_docker_job
    build.save!

    @execution = JobExecution.new(build.git_sha, job) do |_, tmp_dir|
      if build.kubernetes_job
        run_build_image_job(job, push: push, tag_as_latest: tag_as_latest)
      elsif build_image(tmp_dir)
        ret = true
        ret = push_image(tag_as_latest: tag_as_latest) if push
        build.docker_image.remove(force: true) unless ENV["DOCKER_KEEP_BUILT_IMGS"] == "1"
        ret
      end
    end

    @output = @execution.output
    repository.executor = @execution.executor

    @execution.on_complete do
      build.update_column(:finished_at, Time.now)
      send_after_notifications
    end

    JobExecution.start_job(@execution)
  end

  private

  private_class_method def self.create_docker_tarfile(dir)
    dir += '/' unless dir.end_with?('/')
    tempfile_name = Dir::Tmpname.create('out') {}

    # For large git repos, creating a tarfile can do a whole lot of disk IO.
    # It's possible for the puma process to seize up doing all those syscalls,
    # especially if the disk is running slow. So we create the tarfile in a
    # separate process to avoid that.
    tar_proc = -> do
      File.open(tempfile_name, 'wb+') do |tempfile|
        Docker::Util.create_relative_dir_tar(dir, tempfile)
      end
    end

    if Rails.env.test?
      tar_proc.call
    else
      pid = fork(&tar_proc)
      Process.waitpid(pid)
    end

    File.new(tempfile_name, 'r')
  end

  # TODO: not calling before_docker_build hooks since we don't have a temp directory
  # possibly call it anyway with nil so calls do not get lost
  def run_build_image_job(local_job, push: false, tag_as_latest: false)
    k8s_job = Kubernetes::BuildJobExecutor.new(
      output,
      job: local_job,
      registry: DockerRegistry.first
    )
    success, build_log = k8s_job.execute!(
      build, project,
      docker_tag: build.docker_tag,
      push: push,
      tag_as_latest: tag_as_latest
    )

    build.docker_repo_digest = nil

    if success
      build_log.each_line do |line|
        if (match = line[DOCKER_REPO_REGEX, 1])
          build.docker_repo_digest = match
        end
      end
    end
    if build.docker_repo_digest.blank?
      output.puts "### Failed to get the image digest"
    end

    build.save!
  end

  def execute_build_command(tmp_dir, command)
    return unless command
    commands = execution.base_commands(tmp_dir) + command.command.split(/\r?\n|\r/)
    unless execution.executor.execute!(*commands)
      raise Samson::Hooks::UserError, "Error running build command"
    end
  end

  def before_docker_build(tmp_dir)
    Samson::Hooks.fire(:before_docker_repository_usage, build.project)
    Samson::Hooks.fire(:before_docker_build, tmp_dir, build, output)
    execute_build_command(tmp_dir, build.project.build_command)
  end
  add_method_tracer :before_docker_build

  def build_image(tmp_dir)
    File.write("#{tmp_dir}/REVISION", build.git_sha)

    before_docker_build(tmp_dir)

    build.docker_image = DockerBuilderService.build_docker_image(tmp_dir, {}, output)
  rescue Docker::Error::UnexpectedResponseError
    # If the docker library isn't able to find an image id, it returns the
    # entire output of the "docker build" command, which we've already captured
    output.puts("Docker build failed (image id not found in response)")
    nil
  rescue Docker::Error::DockerError => e
    # If a docker error is raised, consider that a "failed" job instead of an "errored" job
    output.puts("Docker build failed: #{e.message}")
    nil
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

    build.save!
    build
  rescue Docker::Error::DockerError => e
    output.puts("Docker push failed: #{e.message}\n")
    nil
  end
  add_method_tracer :push_image

  def push_image_to_registries(tag:, override_tag: false)
    digest = nil

    DockerRegistry.all.each_with_index do |registry, i|
      primary = i.zero?
      repo = project.docker_repo(registry)

      if override_tag
        output.puts("### Tagging and pushing Docker image to #{repo}:#{tag}")
      else
        output.puts("### Pushing Docker image to #{repo}")
      end

      # tag locally so we can push .. otherwise get `Repository does not exist`
      build.docker_image.tag(repo: repo, tag: tag, force: true)

      # push and optionally override tag for the image
      # needs repo_tag to enable pushing to multiple registries
      # otherwise will read first existing RepoTags info
      push_options = {repo_tag: "#{repo}:#{tag}", force: override_tag}

      success = build.docker_image.push(self.class.registry_credentials(registry), push_options) do |chunk|
        parsed_chunk = output.write_docker_chunk(chunk)
        if primary && !digest
          parsed_chunk.each do |output_hash|
            next unless status = output_hash['status']
            next unless sha = status[DIGEST_SHA_REGEX, 1]
            digest = "#{repo}@#{sha}"
          end
        end
      end
      return false unless success
    end

    digest
  end

  def output
    @output ||= OutputBuffer.new
  end

  def repository
    @repository ||= project.repository
  end

  def project
    @build.project
  end

  def send_after_notifications
    Samson::Hooks.fire(:after_docker_build, build)
    SseRailsEngine.send_event('builds', type: 'finish', build: BuildSerializer.new(build, root: nil))
  end
end

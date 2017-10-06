# frozen_string_literal: true
require 'docker'
require 'shellwords'

class DockerBuilderService
  DIGEST_SHA_REGEX = /Digest:.*(sha256:[0-9a-f]+)/i
  DOCKER_REPO_REGEX = /^BUILD DIGEST: (.*@sha256:[0-9a-f]+)/i
  include ::NewRelic::Agent::MethodTracer

  attr_reader :build, :execution

  class << self
    def build_docker_image(dir, output, dockerfile:, tag: nil)
      local_docker_login do |login_commands|
        tag = " -t #{tag.shellescape}" if tag
        file = " -f #{dockerfile.shellescape}"
        build = "docker build#{file}#{tag} ."
        executor = TerminalExecutor.new(output)
        return unless executor.execute(
          "cd #{dir.shellescape}",
          *login_commands,
          executor.verbose_command(build)
        )
        image_id = output.to_s.scan(/Successfully built (\S+)/).last&.first
        Docker::Image.get(image_id) if image_id
      end
    end

    private

    # store logins in a temp file and make it not accidentally added via `ADD .`
    def local_docker_login
      Dir.mktmpdir 'samson-tmp-docker-config' do |docker_config_folder|
        # copy existing credentials
        regular_config = File.join(ENV["DOCKER_CONFIG"] || File.expand_path("~/.docker"), "config.json")
        File.write("#{docker_config_folder}/config.json", File.read(regular_config)) if File.exist?(regular_config)

        # add new temp credentials like ECR ... old docker versions need email and server in last position
        credentials = DockerRegistry.all.select { |r| r.password && r.username }.map do |r|
          username = r.username.shellescape
          password = r.password.shellescape
          email = (docker_major_version >= 17 ? "" : "--email no@example.com ")
          "docker login --username #{username} --password #{password} #{email}#{r.host.shellescape}"
        end

        # run commands and then cleanup after
        yield ["export DOCKER_CONFIG=#{docker_config_folder.shellescape}", *credentials]
      end
    end

    def docker_major_version
      @@docker_major_version ||= begin
        Timeout.timeout(0.2) { read_docker_version[/(\d+)\.\d+\.\d+/, 1].to_i }
      rescue Timeout::Error
        0
      end
    end

    # just here to get stubbed
    def read_docker_version
      `docker -v 2>/dev/null`
    end
  end

  def initialize(build)
    @build = build
  end

  def run(push: false, tag_as_latest: false)
    return unless Rails.cache.write("build-service-#{build.id}", true, unless_exist: true, expires_in: 10.seconds)
    build.docker_build_job&.destroy # if there's an old build job, delete it
    build.docker_tag = build.name&.parameterize.presence || 'latest'
    build.started_at = Time.now

    job = build.create_docker_job
    build.save!

    @execution = JobExecution.new(build.git_sha, job) do |_, tmp_dir|
      if build.kubernetes_job
        run_build_image_job(job, push: push, tag_as_latest: tag_as_latest)
      else
        if build_image(tmp_dir) # rubocop:disable Style/IfInsideElse
          ret = true
          ret = push_image(tag_as_latest: tag_as_latest) if push
          unless ENV["DOCKER_KEEP_BUILT_IMGS"] == "1"
            output.puts("### Deleting local docker image")
            build.docker_image.remove(force: true)
          end
          ret
        else
          output.puts("Docker build failed (image id not found in response)")
          false
        end
      end
    end

    @output = @execution.output
    repository.executor = @execution.executor

    @execution.on_finish do
      build.update_column(:finished_at, Time.now)
      send_after_notifications
    end

    JobExecution.perform_later(@execution)
  end

  private

  # TODO: not calling before_docker_build hooks since we don't have a temp directory
  # possibly call it anyway with nil so calls do not get lost
  def run_build_image_job(local_job, push: false, tag_as_latest: false)
    k8s_job = Kubernetes::BuildJobExecutor.new(
      output,
      job: local_job,
      registry: DockerRegistry.first
    )
    success, build_log = k8s_job.execute(
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
    unless execution.executor.execute(*commands)
      raise Samson::Hooks::UserError, "Error running build command"
    end
  end

  def before_docker_build(tmp_dir)
    Samson::Hooks.fire(:before_docker_repository_usage, build)
    Samson::Hooks.fire(:before_docker_build, tmp_dir, build, output)
    execute_build_command(tmp_dir, build.project.build_command)
  end
  add_method_tracer :before_docker_build

  def build_image(tmp_dir)
    File.write("#{tmp_dir}/REVISION", build.git_sha)

    before_docker_build(tmp_dir)

    build.docker_image = DockerBuilderService.build_docker_image(
      tmp_dir, output, dockerfile: build.dockerfile
    )
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
      repo = project.docker_repo(registry, build.dockerfile)

      if override_tag
        output.puts("### Tagging and pushing Docker image to #{repo}:#{tag}")
      else
        output.puts("### Not Tagging and pushing Docker image to #{repo}")
      end

      # tag locally so we can push .. otherwise get `Repository does not exist`
      build.docker_image.tag(repo: repo, tag: tag, force: true)

      # push and optionally override tag for the image
      # needs repo_tag to enable pushing to multiple registries
      # otherwise will read first existing RepoTags info
      push_options = {repo_tag: "#{repo}:#{tag}", force: override_tag}

      success = build.docker_image.push(registry_credentials(registry), push_options) do |chunk|
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

  # might be able to get rid of this if we transition everything to use docker via cli
  def registry_credentials(registry)
    return unless registry.present?
    {
      username: registry.username,
      password: registry.password,
      email: ENV['DOCKER_REGISTRY_EMAIL'],
      serveraddress: registry.host
    }
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

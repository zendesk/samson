require 'docker'

class DockerBuilderService
  DIGEST_SHA_REGEX = /Digest:.*(sha256:[0-9a-f]+)/i

  attr_reader :build, :image

  def initialize(build)
    @build = build
  end

  def build!(image_name: nil, push: false)
    # TODO: check if there's already a docker build

    job = build.create_docker_job
    build.save!

    job_execution = JobExecution.start_job(build.git_sha, job) do |execution, tmp_dir|
      if build_image(execution, tmp_dir) && push
        push_image(execution.output, image_name)
      end
    end

    job_execution.subscribe do
      send_after_notifications
    end
  end

  def push_image(output_buffer, tag)
    build.docker_ref = tag || build.label.try(:parameterize) || 'latest'
    build.docker_image.tag(repo: project.docker_repo, tag: build.docker_ref, force: true)

    output_buffer.puts("### Pushing Docker image to #{project.docker_repo}:#{build.docker_ref}")

    build.docker_image.push do |output_chunk|
      output_buffer.puts(output_chunk)

      status = JSON.parse(output_chunk).fetch('status', '')
      if (matches = DIGEST_SHA_REGEX.match(status))
        build.docker_repo_digest = "#{project.docker_repo}@#{matches[1]}"
      end
    end

    build.save!

    build
  rescue Docker::Error::DockerError => e
    output_buffer.puts("Docker push failed: #{e.message}\n")
    nil
  end


  private

  def build_image(execution, tmp_dir)
    repository.executor = execution.executor
    repository.setup!(tmp_dir, build.git_sha)

    File.open("#{tmp_dir}/REVISION", 'w') { |f| f.write build.git_sha }

    execution.output.puts("### Running Docker build")

    build.docker_image = Docker::Image.build_from_dir(tmp_dir) do |output_chunk|
      execution.output.puts(output_chunk)
    end
  rescue Docker::Error::DockerError => e
    # If a docker error is raised, consider that a "failed" job instead of an "errored" job
    execution.output.puts("Docker build failed: #{e.message}")
    nil
  end

  def repository
    @repository ||= project.repository
  end

  def project
    @build.project
  end

  def send_after_notifications
    Samson::Hooks.fire(:after_docker_build, build)
    SseRailsEngine.send_event('builds', { type: type, build: BuildSerializer.new(build, root: nil) })
  end
end

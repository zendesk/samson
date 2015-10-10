require 'docker'

class DockerBuilderService
  DIGEST_SHA_REGEX = /Digest:.*(sha256:[0-9a-f]+)/i

  attr_reader :build, :execution

  def initialize(build)
    @build = build
  end

  def run!(image_name: nil, push: false)
    job = build.create_docker_job
    build.save!

    job_execution = JobExecution.start_job(
      build.git_sha, job,
      on_complete: method(:send_after_notifications),
      &method(:execute)
    )
  end

  def execute(execution, tmp_dir)
    @execution = execution
    @output_buffer = execution.output
    repository.executor = execution.executor

    if build_image(tmp_dir) && push
      push_image(image_name)
    end
  end

  def build_image(tmp_dir)
    repository.setup!(tmp_dir, build.git_sha)
    Samson::Hooks.fire(:before_docker_build, tmp_dir, build, output_buffer)

    File.write("#{tmp_dir}/REVISION", build.git_sha)

    output_buffer.puts("### Running Docker build")

    build.docker_image = Docker::Image.build_from_dir(tmp_dir) do |output_chunk|
      handle_output_chunk(output_chunk)
    end
  rescue Docker::Error::DockerError => e
    # If a docker error is raised, consider that a "failed" job instead of an "errored" job
    output_buffer.puts("Docker build failed: #{e.message}")
    nil
  end

  def push_image(tag)
    build.docker_ref = tag || build.label.try(:parameterize) || 'latest'
    build.docker_image.tag(repo: project.docker_repo, tag: build.docker_ref, force: true)

    output_buffer.puts("### Pushing Docker image to #{project.docker_repo}:#{build.docker_ref}")

    build.docker_image.push do |output_chunk|
      parsed_chunk = handle_output_chunk(output_chunk)

      status = parsed_chunk.fetch('status', '')
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

  def output_buffer
    @output_buffer ||= OutputBuffer.new
  end

  private

  def repository
    @repository ||= project.repository
  end

  def project
    @build.project
  end

  def handle_output_chunk(chunk)
    parsed_chunk = JSON.parse(chunk)
    values = parsed_chunk.each_with_object([]) do |(k,v), arr|
      arr << "#{k}: #{v}" if v.present?
    end

    output_buffer.puts values.join(' | ')
    parsed_chunk
  end

  def send_after_notifications
    Samson::Hooks.fire(:after_docker_build, build)
    SseRailsEngine.send_event('builds', { type: 'finish', build: BuildSerializer.new(build, root: nil) })
  end
end

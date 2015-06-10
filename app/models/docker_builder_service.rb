require 'docker'

class DockerBuilderService
  attr_reader :build, :image

  def initialize(build)
    @build = build
  end

  def build!(image_name: nil, push: false)
    # TODO: check if there's already a docker build

    job = build.create_docker_job
    build.save!

    job_execution = JobExecution.start_job(build.git_sha, job) do |execution, tmp_dir|
      build_image(execution, tmp_dir, image_name, push)
    end

    job_execution.subscribe do
      send_after_notifications
    end
  end

  private

  def build_image(execution, tmp_dir, image_name, push)
    repository.executor = execution.executor
    repository.setup!(tmp_dir, build.git_sha)

    File.open("#{tmp_dir}/REVISION", 'w') { |f| f.write build.git_sha }

    execution.output.write("### Running Docker build")

    @image = Docker::Image.build_from_dir(tmp_dir) do |output_chunk|
      execution.output.write(parse_output_chunk(output_chunk))
    end

    build.docker_sha = @image.json['Id']
    build.docker_ref = image_name || build.label || 'latest'
    build.docker_image_url = "#{docker_registry_url}/#{build.project.docker_repo_name}@sha256:#{build.docker_sha}"
    build.save!

    @image.tag(repo: build.project.docker_repo_name, tag: build.docker_ref, force: true)

    if push
      # TODO: authenticate with the Docker registry
      execution.output.write "### Pushing Docker image to #{build.project.docker_repo_name}/#{build.docker_ref}"
      @image.push do |output_chunk|
        execution.output.write(parse_output_chunk(output_chunk))
      end
    end

    @image
  end

  def docker_registry_url
    # TODO: update this with an ENV var
    'docker-registry.zende.sk'
  end

  def parse_output_chunk(chunk)
    JSON.parse(chunk)['stream']
  rescue JSON::ParserError
    chunk
  end

  def repository
    @repository ||= @build.project.repository
  end

  def send_after_notifications
    Samson::Hooks.fire(:after_docker_build, build)
    SseRailsEngine.send_event('builds', { type: type, build: BuildSerializer.new(build, root: nil) })
  end
end

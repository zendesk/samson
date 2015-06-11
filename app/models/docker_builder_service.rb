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

    execution.output.write("### Running Docker build\n")

    @image = Docker::Image.build_from_dir(tmp_dir) do |output_chunk|
      execution.output.write(parse_output_chunk(output_chunk))
    end

    build.update_docker_image_attributes(digest: @image.json['Id'], tag: image_name)
    build.save!

    @image.tag(repo: build.project.docker_repo_name, tag: build.docker_ref, force: true)

    if push
      execution.output.write "### Pushing Docker image to #{image_name_with_tag}\n"
      @image.push do |output_chunk|
        execution.output.write(parse_output_chunk(output_chunk))
      end
    end

    @image
  rescue Docker::Error::DockerError => e
    # If a docker error is raised, consider that a "failed" job instead of an "errored" job
    message = "Docker build failed: #{e.message}"
    @output.write(message + "\n")
    nil
  end

  def image_name_with_tag
    "#{Rails.application.config.samson.docker.registry}/#{build.project.docker_repo_name}:#{build.docker_ref}"
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

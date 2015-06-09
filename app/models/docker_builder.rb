
class DockerImageBuilder
  attr_reader :build

  def initialize(build)
    @build = build
  end

  def build!(image_name: nil, push: true)
    image = build_image

    build.container_sha = image.id
    build.container_ref = image_name || build.git_ref || 'master'
    build.save!

    image.tag(tag: build.container_ref)

    # TODO: figure out how to authenticate with the Docker registry
    image.push if push

    image
  end

  private

  def build_image
    Dir.mktmpdir do |tmp_dir|
      repository.setup!(TerminalExecutor.new(output, verbose: true), tmp_dir, build.git_sha)

      Docker::Image.build_from_dir(tmp_dir) do |build_output_chunk|
        output.write(build_output_chunk)
      end
    end
  end

  def repository
    @repository ||= @build.project.repository
  end

  def output
    @output ||= OutputBuffer.new
  end
end

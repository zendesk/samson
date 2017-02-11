# frozen_string_literal: true
class BinaryBuilder
  DOCKER_BUILD_FILE = 'Dockerfile.build'
  BUILD_SCRIPT = '/app/build.sh'
  ARTIFACTS_FILE = 'artifacts.tar'
  ARTIFACTS_FILE_PATH = "/app/#{ARTIFACTS_FILE}"
  DOCKER_HOST_CACHE_DIR = '/opt/samson_build_cache'
  CONTAINER_CACHE_DIR = '/build/cache'
  TAR_LONGLINK = '././@LongLink'
  PRE_BUILD_SCRIPT = 'pre_binary_build.sh'

  def initialize(dir, project, reference, output, executor = nil)
    @dir = dir
    @project = project
    @git_reference = reference
    @output = output
    @executor = executor || TerminalExecutor.new(@output, verbose: true)
  end

  def build
    return unless build_file_exist?

    begin
      run_pre_build_script

      @output.puts "Connecting to Docker host with Api version: #{docker_api_version} ..."

      @image = create_build_image
      @container = Docker::Container.create(create_container_options)

      start_build_script
      retrieve_binaries

      @output.puts 'Continuing docker build...'
    ensure
      @output.puts 'Cleaning up docker build image and container...'
      @container&.delete(force: true)
      @image&.remove(force: true)
    end
  end

  def run_pre_build_script
    pre_build_file = File.join(@dir, PRE_BUILD_SCRIPT)
    return unless File.file? pre_build_file

    @output.puts "Running pre build script..."
    unless @executor.execute! pre_build_file
      raise Samson::Hooks::UserError, "Error running pre build script"
    end
  end

  private

  def build_file_exist?
    File.exist?(File.join(@dir, DOCKER_BUILD_FILE)) &&
      File.exist?(File.join(@dir, File.basename(BUILD_SCRIPT)))
  end

  def start_build_script
    @output.puts 'Now starting Build container...'
    @container.tap(&:start).attach { |_stream, chunk| @output.write_docker_chunk(chunk) }
  rescue
    raise_as_user_error "Binary builder error: Failed to run the build script '#{BUILD_SCRIPT}' inside container", $!
  end

  def retrieve_binaries
    @output.puts "Grabbing '#{ARTIFACTS_FILE_PATH}' from build container..."
    artifacts_tar = Tempfile.new(['artifacts', '.tar'], @dir)
    artifacts_tar.binmode
    @container.copy(ARTIFACTS_FILE_PATH) { |chunk| artifacts_tar.write chunk }
    artifacts_tar.close

    untar(artifacts_tar.path)
    untar(File.join(@dir, ARTIFACTS_FILE))
  rescue
    raise_as_user_error "Unable to extract artifact from container", $!
  end

  # FIXME: does not set permissons ... reuse some library instead of re-inventing
  def untar(file_path)
    @output.puts "About to untar: #{file_path}"

    File.open(file_path, 'rb') do |io|
      Gem::Package::TarReader.new io do |tar|
        tar.each do |tarfile|
          destination_file = File.join @dir, tarfile.full_name
          @output.puts "    > #{tarfile.full_name}"

          if tarfile.directory?
            FileUtils.mkdir_p destination_file
          else
            destination_directory = File.dirname(destination_file)
            FileUtils.mkdir_p destination_directory unless File.directory?(destination_directory)
            File.open(destination_file, "wb") { |f| f.print tarfile.read }
          end
        end
      end
    end
  end

  def create_container_options
    options = {
      'Cmd' => [BUILD_SCRIPT],
      'Image' => image_name,
      'Env' => env_vars_for_project
    }

    # Mount a cache directory for sharing .m2, .ivy2, .bundler directories between build containers.
    api_version_major, api_version_minor = docker_api_version.scan(/(\d+)\.(\d+)/).flatten.map(&:to_i)
    if api_version_major.zero? || (api_version_major == 1 && api_version_minor <= 14)
      fail "Unsupported Docker api version '#{docker_api_version}', use at least v1.15"
    elsif api_version_major == 1 && api_version_minor <= 22
      options.merge!(
        'Volumes' => {
          DOCKER_HOST_CACHE_DIR => {}
        },
        'HostConfig' => {
          'Binds' => ["#{DOCKER_HOST_CACHE_DIR}:#{CONTAINER_CACHE_DIR}"],
          'NetworkMode' => 'host'
        }
      )
    else
      options.merge!(
        'Mounts' => [
          {
            'Source' => DOCKER_HOST_CACHE_DIR,
            'Destination' => CONTAINER_CACHE_DIR,
            'Mode' => 'rw,Z',
            'RW' => true
          }
        ],
        'HostConfig' => {
          'NetworkMode' => 'host'
        }
      )
    end
  end

  def image_name
    "#{@project.send(:permalink_base)}_build:#{@git_reference.parameterize}".downcase
  end

  def create_build_image
    build_options = {
      'dockerfile' => DOCKER_BUILD_FILE,
      't' => image_name
    }
    DockerBuilderService.build_docker_image(@dir, build_options, @output)
  end

  def docker_api_version
    @docker_api_version ||= Docker.version['ApiVersion']
  end

  # TODO: not sure what happens when value is shell safe "foo;\n;bar"
  def env_vars_for_project
    if env_plugin_enabled?
      EnvironmentVariable.env(@project, nil).map { |name, value| "#{name}=#{value}" }
    else
      []
    end
  end

  def env_plugin_enabled?
    defined?(EnvironmentVariable)
  end

  def raise_as_user_error(message, error)
    Rails.logger.error("#{message}:\n#{error}\n#{error.backtrace.join("\n")}")
    raise Samson::Hooks::UserError, "#{message}\n#{error}"
  end
end

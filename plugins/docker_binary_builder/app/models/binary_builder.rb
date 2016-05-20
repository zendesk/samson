class BinaryBuilder
  DOCKER_BUILD_FILE = 'Dockerfile.build'.freeze
  BUILD_SCRIPT = '/app/build.sh'.freeze
  ARTIFACTS_FILE = 'artifacts.tar'.freeze
  ARTIFACTS_FILE_PATH = "/app/#{ARTIFACTS_FILE}".freeze
  DOCKER_HOST_CACHE_DIR = '/opt/samson_build_cache'.freeze
  CONTAINER_CACHE_DIR = '/build/cache'.freeze
  TAR_LONGLINK = '././@LongLink'.freeze
  PRE_BUILD_SCRIPT = 'pre_binary_build.sh'.freeze

  def initialize(dir, project, reference, output, executor = nil)
    @dir = dir
    @project = project
    @git_reference = reference
    @output_stream = output
    @executor = executor || TerminalExecutor.new(@output_stream, verbose: true)
  end

  def build
    return unless @project.try(:deploy_with_docker?) && build_file_exist?

    run_pre_build_script

    @output_stream.puts "Connecting to Docker host with Api version: #{docker_api_version} ..."

    @image = create_build_image
    @container = Docker::Container.create(create_container_options)

    start_build_script
    retrieve_binaries

    @output_stream.puts 'Continuing docker build...'
  ensure
    @output_stream.puts 'Cleaning up docker build image and container...'
    @container.delete(force: true) if @container
    @image.remove(force: true) if @image
  end

  def run_pre_build_script
    return unless pre_build_file_exist?

    @output_stream.puts "Running pre build script..."
    success = @executor.execute! pre_build_file

    raise "Error running pre build script" unless success
  end

  private

  def pre_build_file
    File.join(@dir, PRE_BUILD_SCRIPT)
  end

  def pre_build_file_exist?
    File.file? pre_build_file
  end

  def build_file_exist?
    File.exist? File.join(@dir, DOCKER_BUILD_FILE)
  end

  def start_build_script
    @output_stream.puts 'Now starting Build container...'
    @container.tap(&:start).attach { |_stream, chunk| @output_stream.write chunk }
  rescue => ex
    @output_stream.puts "Failed to run the build script '#{BUILD_SCRIPT}' inside container."
    raise ex
  end

  def retrieve_binaries
    @output_stream.puts "Grabbing '#{ARTIFACTS_FILE_PATH}' from build container..."
    artifacts_tar = Tempfile.new(['artifacts', '.tar'], @dir)
    artifacts_tar.binmode
    @container.copy(ARTIFACTS_FILE_PATH) { |chunk| artifacts_tar.write chunk }
    artifacts_tar.close

    untar(artifacts_tar.path)
    untar(File.join(@dir, ARTIFACTS_FILE))
  end

  def untar(file_path)
    @output_stream.puts "About to untar: #{file_path}"

    File.open(file_path, 'rb') do |io|
      Gem::Package::TarReader.new io do |tar|
        tar.each do |tarfile|
          destination_file = File.join @dir, tarfile.full_name
          @output_stream.puts "    > #{tarfile.full_name}"

          if tarfile.directory?
            FileUtils.mkdir_p destination_file
          else
            destination_directory = File.dirname(destination_file)
            FileUtils.mkdir_p destination_directory unless File.directory?(destination_directory)
            File.open destination_file, "wb" do |f|
              f.print tarfile.read
            end
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
    if api_version_major == 0 || (api_version_major == 1 && api_version_minor <= 14)
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
    "#{@project.send(:permalink_base)}_build:#{@git_reference}".downcase
  end

  def create_build_image
    @output_stream.puts 'Now building the build container...'
    Docker::Image.build_from_dir(
      @dir, 'dockerfile' => DOCKER_BUILD_FILE, 't' => image_name
    ) { |chunk| @output_stream.write chunk }
  end

  def docker_api_version
    @docker_api_version ||= Docker.version['ApiVersion']
  end

  def env_vars_for_project
    if defined?(EnvironmentVariable) # make sure 'env' plugin is enabled
      EnvironmentVariable.env(@project, nil).map { |name, value| "#{name}=#{value}" }
    else
      []
    end
  end
end

# frozen_string_literal: true
require 'docker'

if !Rails.env.test? && !ENV['PRECOMPILE'] && ENV['DOCKER_FEATURE']
  DockerRegistry.check_config!

  # Check DOCKER_URL for backwards-compatibility
  if (url = ENV['DOCKER_HOST'].presence || ENV['DOCKER_URL'].presence)
    Docker.url = url
  end

  Docker.options = {
    read_timeout: Integer(ENV['DOCKER_READ_TIMEOUT'] || '10'),
    connect_timeout: 2,
    nonblock: true
  }

  begin
    Docker.validate_version! # Confirm the Docker daemon is a recent enough version
  rescue Docker::Error::TimeoutError, Excon::Error::Socket
    warn "Unable to connect to docker!"
    Airbrake.notify($!)
  end

  # ensure that --cache-from is supported (v13+)
  min_version = 13
  begin
    local = Timeout.timeout(1) do
      Integer(`docker -v`[/Docker version (\d+)/, 1])
    end
    server = Integer(Docker.version.fetch("Version")[/\d+/, 0])
    if local < min_version || server < min_version
      raise Docker::Error::VersionError, "Expected docker version to be >= #{min_version}"
    end
  rescue
    warn "Unable to verify local docker!"
    Airbrake.notify($!)
  end
end

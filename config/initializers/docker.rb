# frozen_string_literal: true
require 'docker'

if !Rails.env.test? && !ENV['PRECOMPILE'] && ENV['DOCKER_FEATURE']
  DockerRegistry.check_config!

  # Check DOCKER_URL for backwards-compatibility
  if (url = ENV['DOCKER_HOST'].presence || ENV['DOCKER_URL'].presence)
    Docker.url = url
  end

  Docker.options = { read_timeout: 600, connect_timeout: 2 }
  Docker.validate_version! # Confirm the Docker daemon is a recent enough version
end

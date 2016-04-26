require 'docker'

if !Rails.env.test? && !ENV['PRECOMPILE'] && ENV['DOCKER_FEATURE']
  if ENV['DOCKER_REGISTRY'].blank?
    puts '*** DOCKER_REGISTRY environment variable must be configured when DOCKER_FEATURE is enabled ***'
    exit 1
  end

  if (url = ENV['DOCKER_URL'].presence)
    Docker.url = url
  end

  Docker.options = { read_timeout: 600, connect_timeout: 2 }
  Docker.validate_version! # Confirm the Docker daemon is a recent enough version
end

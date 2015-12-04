require 'docker'

if !Rails.env.test? && !ENV['PRECOMPILE']
  if ENV['DOCKER_URL'].present?
    Docker.url = ENV['DOCKER_URL']
    Docker.options = { read_timeout: 600 }

    # Confirm the Docker daemon is a recent enough version
    Docker.validate_version!
  end

  if ENV['DOCKER_FEATURE'] && !ENV['DOCKER_REGISTRY'].present?
    puts '*** DOCKER_REGISTRY environment variable must be configured when DOCKER_FEATURE is enabled ***'
    exit(1)
  end

  # Authenticate to the Docker registry if required
  if %w(DOCKER_REGISTRY DOCKER_REGISTRY_USER DOCKER_REGISTRY_PASS DOCKER_REGISTRY_EMAIL).all? {|key| ENV[key].present? }
    Docker.authenticate!(
      username: ENV['DOCKER_REGISTRY_USER'],
      password: ENV['DOCKER_REGISTRY_PASS'],
      email: ENV['DOCKER_REGISTRY_EMAIL'])
    puts "Authenticated for the Docker Registry #{ENV['DOCKER_REGISTRY']}"
  end
end

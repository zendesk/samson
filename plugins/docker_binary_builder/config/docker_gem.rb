# frozen_string_literal: true
require 'docker'

if !Rails.env.test? && !ENV['PRECOMPILE'] && ENV['DOCKER_FEATURE']
  # Check DOCKER_URL for backwards-compatibility
  if (url = ENV['DOCKER_HOST'].presence || ENV['DOCKER_URL'].presence)
    Docker.url = url
  end

  Docker.options = {
    read_timeout: Integer(ENV['DOCKER_READ_TIMEOUT'] || '10'),
    connect_timeout: 2,
    nonblock: true
  }
end

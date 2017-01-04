# frozen_string_literal: true

class DockerRegistry
  class << self
    def check_config!
      if ENV['DOCKER_REGISTRIES'].blank? && ENV['DOCKER_REGISTRY'].blank?
        abort '*** DOCKER_REGISTRIES environment variable must be configured when DOCKER_FEATURE is enabled ***'
      end
    end

    def all
      @all ||= begin
        registries = ENV['DOCKER_REGISTRIES'] || deprecated_registry
        registries.to_s.split(',').map { |url| new(url) }
      end
    end

    def first
      all.first
    end

    private

    def deprecated_registry
      return unless registry = ENV['DOCKER_REGISTRY']
      warn "Using deprecated DOCKER_REGISTRY, prefer DOCKER_REGISTRIES"

      if user = ENV['DOCKER_REGISTRY_USER']
        login = "#{user}:#{ENV['DOCKER_REGISTRY_PASS']}@"
      end

      if namespace = ENV["DOCKER_REPO_NAMESPACE"]
        namespace = "/#{namespace}"
      end

      "https://#{login}#{registry}#{namespace}"
    end
  end

  attr_accessor :username, :password, :credentials_expire_at # modified by ECR plugin

  def initialize(url)
    url = "https://#{url}" unless url.include?("://")
    @uri = URI.parse(url)
    @username = @uri.user
    @password = @uri.password
  end

  def host
    @uri.host
  end

  def base
    @uri.host + @uri.path
  end
end

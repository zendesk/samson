# frozen_string_literal: true
require 'aws-sdk-ecr'

module SamsonAwsEcr
  class SamsonPlugin < Rails::Engine
    AMAZON_REGISTRY = /\A.*\.dkr.ecr.([\w\-]+).amazonaws.com\z/.freeze

    class << self
      # we make sure the repo exists so pushes do not fail
      # - ignores if the repo already exists
      # - ignores if the repo cannot be created due to permission problems
      def ensure_repositories(build)
        DockerRegistry.all.each do |registry|
          next unless client = ecr_client(registry)
          name = build.project.docker_repo(registry, build.dockerfile).split('/', 2).last

          begin
            begin
              client.describe_repositories(repository_names: [name])
            rescue Aws::ECR::Errors::RepositoryNotFoundException
              client.create_repository(repository_name: name)
            end
          rescue Aws::ECR::Errors::AccessDenied
            Rails.logger.info("Not allowed to create or describe repositories")
          end
        end
      end

      # aws credentials are only valid for a limited time, so we need to refresh them before pushing
      def refresh_credentials
        DockerRegistry.all.each do |registry|
          next if registry.credentials_expire_at&.> 1.hour.from_now
          next unless client = ecr_client(registry)

          authorization_data = client.get_authorization_token.authorization_data.first
          username, password = Base64.decode64(authorization_data.authorization_token).split(":", 2)
          registry.username = username
          registry.password = password
          registry.credentials_expire_at = authorization_data.expires_at || raise("NO EXPIRE FOUND")
        end
      rescue Aws::ECR::Errors::InvalidSignatureException
        raise Samson::Hooks::UserError, "Invalid AWS credentials"
      end

      def active?
        DockerRegistry.all.any? { |registry| ecr_client(registry) }
      end

      private

      attr_accessor :credentials_expire_at

      def ecr_client(registry)
        host = registry.host
        @ecr_clients ||= {}
        @ecr_clients.fetch(host) do
          @ecr_clients[host] = (region = host[AMAZON_REGISTRY, 1]) && Aws::ECR::Client.new(region: region)
        end
      end
    end
  end
end

# need credentials to pull (via Dockerfile FROM) and push images
# ATM this only authenticates the default docker registry and not any extra registries
Samson::Hooks.callback :before_docker_repository_usage do |build|
  SamsonAwsEcr::SamsonPlugin.ensure_repositories(build)
  SamsonAwsEcr::SamsonPlugin.refresh_credentials
end

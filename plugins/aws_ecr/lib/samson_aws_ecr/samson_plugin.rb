# frozen_string_literal: true
require 'aws-sdk-core'

module SamsonAwsEcr
  class Engine < Rails::Engine
    AMAZON_REGISTRY = /\A.*\.dkr.ecr.(?<region>[\w\-]+).amazonaws.com\z/

    class << self
      # we make sure the repo exists so pushes do not fail
      # - ignores if the repo already exists
      # - ignores if the repo cannot be created due to permission problems
      def ensure_repository(repository)
        begin
          return unless ecr_client
          name = repository.split('/', 2).last
          ecr_client.describe_repositories(repository_names: [name])
        rescue Aws::ECR::Errors::RepositoryNotFoundException
          ecr_client.create_repository(repository_name: name)
        end
      rescue Aws::ECR::Errors::AccessDenied
        Rails.logger.info("Not allowed to create or describe repositories")
      end

      # aws credentials are only valid for a limited time, so we need to refresh them before pushing
      def refresh_credentials
        if credentials_stale?
          authorization_data = ecr_client.get_authorization_token.authorization_data.first

          self.credentials_expire_at = authorization_data.expires_at || raise("NO EXPIRE FOUND")
          user, pass = Base64.decode64(authorization_data.authorization_token).split(":", 2)
          ENV['DOCKER_REGISTRY_USER'] = user
          ENV['DOCKER_REGISTRY_PASS'] = pass
        end
      rescue Aws::ECR::Errors::InvalidSignatureException
        raise Samson::Hooks::UserError, "Invalid AWS credentials"
      end

      private

      attr_accessor :credentials_expire_at

      def ecr_client
        return @ecr_client if defined?(@ecr_client)
        @ecr_client = if match = AMAZON_REGISTRY.match(Rails.application.config.samson.docker.registry)
          Aws::ECR::Client.new(region: match['region'])
        end
      end

      def credentials_stale?
        ecr_client && (!credentials_expire_at || credentials_expire_at < 1.hour.from_now)
      end
    end
  end
end

# need credentials to pull (via Dockerfile FROM) and push images
Samson::Hooks.callback :before_docker_build do |_, build, _|
  SamsonAwsEcr::Engine.ensure_repository(build.project.docker_repo)
  SamsonAwsEcr::Engine.refresh_credentials
end

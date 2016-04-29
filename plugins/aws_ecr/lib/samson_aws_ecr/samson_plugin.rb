require 'aws-sdk-core'

module SamsonAwsEcr
  class Engine < Rails::Engine
    AMAZON_REGISTRY = /\A.*\.dkr.ecr.(?<region>[\w\-]+).amazonaws.com\z/
    mattr_accessor :ecr_client
    mattr_accessor(:credentials_expire_at) { Time.current }

    initializer :ecr_client do
      if match = AMAZON_REGISTRY.match(ENV['DOCKER_REGISTRY'])
        SamsonAwsEcr::Engine.ecr_client = Aws::ECR::Client.new(region: match['region'])
      end
    end
  end
end

Samson::Hooks.callback :before_docker_build do
  begin
    if SamsonAwsEcr::Engine.ecr_client && SamsonAwsEcr::Engine.credentials_expire_at < Time.current
      authorization_token = SamsonAwsEcr::Engine.ecr_client.get_authorization_token
      authorization_data  = authorization_token.authorization_data.first

      SamsonAwsEcr::Engine.credentials_expire_at = authorization_data.expires_at || raise("NO EXPIRE FOUND")
      user, pass = Base64.decode64(authorization_data.authorization_token).split(":")
      ENV['DOCKER_REGISTRY_USER'] = user
      ENV['DOCKER_REGISTRY_PASS'] = pass
    end
  rescue Aws::ECR::Errors::InvalidSignatureException
    Rails.logger.error("Invalid AWS credentials")
  end
end

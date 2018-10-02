module SamsonAwsSts
  ROLE_SESSION_NAME = 'StaticAssetsPipeline'

  class Engine < Rails::Engine
  end

  class << self
    def set_env_vars(sts_client:, stage:)
      creds = sts_client.assume_role(
        role_arn: stage.aws_sts_iam_role_arn,
        role_session_name: ROLE_SESSION_NAME
      ).credentials

      ENV['STS_AWS_ACCESS_KEY_ID']     = creds.access_key_id
      ENV['STS_AWS_SECRET_ACCESS_KEY'] = creds.secret_access_key
      ENV['STS_AWS_SESSION_TOKEN']     = creds.session_token
    end
  end
end

Samson::Hooks.view :stage_form, 'samson_aws_sts/fields'

Samson::Hooks.callback :stage_permitted_params do
  [
    :aws_sts_iam_role_arn
  ]
end

Samson::Hooks.callback :before_deploy do |deploy, _buddy|
  # https://docs.aws.amazon.com/sdkforruby/api/Aws/STS/Client.html
  # Default credentials are loaded automatically from the following locations:
  # ENV['AWS_ACCESS_KEY_ID'] and ENV['AWS_SECRET_ACCESS_KEY']
  # Region is loaded from ENV['AWS_REGION']
  SamsonAwsSts.set_env_vars(
    sts_client: Aws::STS::Client.new,
    stage: deploy.stage
  )
end

# frozen_string_literal: true
require 'aws-sdk-core'

module SamsonAwsSts
  SESSION_DURATION_MIN = 900 # 15 minutes
  SESSION_DURATION_MAX = [SESSION_DURATION_MIN, Rails.application.config.samson.deploy_timeout].max

  class Engine < Rails::Engine
  end

  def self.sts_client
    options = {
      access_key_id:     ENV['SAMSON_STS_AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['SAMSON_STS_AWS_SECRET_ACCESS_KEY'],
      region:            ENV['SAMSON_STS_AWS_REGION'],
    }
    return if options.any? { |_, v| v.blank? }

    options[:stub_responses] = Rails.env.test?

    Client.new(Aws::STS::Client.new(options))
  end

  class Client
    def initialize(sts_client)
      @sts_client = sts_client
    end

    def caller_user_id
      @sts_client.get_caller_identity[:user_id]
    end

    def deploy_env_vars(deploy)
      creds = assume_role(
        role_arn: deploy.stage.aws_sts_iam_role_arn,
        role_session_name: session_name(deploy),
        duration_seconds: deploy.stage.aws_sts_iam_role_session_duration || SESSION_DURATION_MIN
      ).credentials

      {
        STS_AWS_ACCESS_KEY_ID:     "hidden://#{creds.access_key_id}",
        STS_AWS_SECRET_ACCESS_KEY: "hidden://#{creds.secret_access_key}",
        STS_AWS_SESSION_TOKEN:     "hidden://#{creds.session_token}"
      }
    end

    def assume_role(role_arn:, role_session_name:, duration_seconds:)
      @sts_client.assume_role(
        role_arn: role_arn,
        role_session_name: role_session_name,
        duration_seconds: duration_seconds
      )
    end

    private

    def session_name(deploy)
      project_name = deploy.project.name.parameterize[0..15].tr('_', '-')
      stage_name   = deploy.stage.name.parameterize[0..15].tr('_', '-')

      "#{project_name}-#{stage_name}-deploy-#{deploy.id}"
    end
  end
end

Samson::Hooks.view :stage_form, 'samson_aws_sts/fields'

Samson::Hooks.callback :stage_permitted_params do
  [
    :aws_sts_iam_role_arn,
    :aws_sts_iam_role_session_duration
  ]
end

Samson::Hooks.callback :deploy_execution_env do |deploy|
  next {} if deploy.stage.aws_sts_iam_role_arn.blank?
  SamsonAwsSts::Client.new(SamsonAwsSts.sts_client).deploy_env_vars(deploy)
end

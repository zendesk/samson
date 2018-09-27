# frozen_string_literal: true
require 'aws-sdk'

class STSCredentials
  def initialize(deploy)
    @deploy = deploy
    @stage = @deploy.stage
    @project = @stage.project
  end

  def create
    #Initial client to assume role
    sts_clt = Aws::STS::Client.new(
        access_key_id: ENV("samson trusted user key"),
        secret_access_key: ENV("samson trusted user secret"),
        region: agent_region
    )

    #Obtain credentials with initial client
    creds = Aws::AssumeRoleCredentials.new(
        client: sts_clt,
        role_arn: deploy.stage.aws_sts_iam_role_arn,
        role_session_name: 'StaticAssetsPipeline'
    )

    #Set environment variables

  end
end

# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: 4

describe SamsonAwsSts do
  let(:stage) { stages(:test_staging) }

  def deploy_env_vars(stage)
    SamsonAwsSts::Client.new(
      Aws::STS::Client.new(stub_responses: true)
    ).deploy_env_vars(deploy: stage.deploys.last)
  end

  describe '.sts_client' do
    it 'returns nil if env vars are missing' do
      SamsonAwsSts.sts_client.must_equal nil
    end
  end

  describe '#deploy_env_vars' do
    it 'returns a hash of additional env variables' do
      stage.aws_sts_iam_role_arn = "some_arn"

      deploy_env_vars(stage).must_equal(
        STS_AWS_ACCESS_KEY_ID:     'hidden://accessKeyIdType',
        STS_AWS_SECRET_ACCESS_KEY: 'hidden://accessKeySecretType',
        STS_AWS_SESSION_TOKEN:     'hidden://tokenType'
      )
    end
  end

  describe '#assume_role' do
    it "delegates to the embedded sts client" do
      Aws::STS::Client.any_instance.expects(:assume_role).with(
        role_arn: 'arn',
        role_session_name: 'session',
        duration_seconds: 900
      )
      SamsonAwsSts::Client.new(
        Aws::STS::Client.new(stub_responses: true)
      ).assume_role(role_arn: 'arn', role_session_name: 'session')
    end
  end

  describe '#caller_user_id' do
    it 'returns the user id' do
      SamsonAwsSts::Client.new(
        Aws::STS::Client.new(stub_responses: true)
      ).caller_user_id.must_equal 'userIdType'
    end
  end

  describe 'stage_permitted_params callback' do
    it 'returns attributes used by the plugin' do
      Samson::Hooks.only_callbacks_for_plugin('samson_aws_sts', :stage_permitted_params) do
        Samson::Hooks.fire(:stage_permitted_params).must_equal(
          [%i[
            aws_sts_iam_role_arn
            aws_sts_iam_role_session_duration
          ]]
        )
      end
    end
  end

  describe 'deploy_env_vars callback' do
    it 'calls SamsonAwsSts.deploy_env_vars' do
      stage.aws_sts_iam_role_arn = "some_arn"

      SamsonAwsSts.stubs(:sts_client).returns(Aws::STS::Client.new(stub_responses: true))
      Samson::Hooks.only_callbacks_for_plugin('samson_aws_sts', :deploy_env) do
        Samson::Hooks.fire(:deploy_env, stage.deploys.last)
      end
    end
  end
end

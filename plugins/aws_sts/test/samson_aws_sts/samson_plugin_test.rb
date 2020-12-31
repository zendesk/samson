# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SamsonAwsSts do
  let(:stage) { stages(:test_staging) }

  with_env SAMSON_STS_AWS_ACCESS_KEY_ID: 'x', SAMSON_STS_AWS_SECRET_ACCESS_KEY: 'y', SAMSON_STS_AWS_REGION: 'z'

  describe '.sts_client' do
    it 'builds when all env vars are set' do
      assert SamsonAwsSts.sts_client
    end

    it 'returns nil if env vars are missing' do
      with_env SAMSON_STS_AWS_ACCESS_KEY_ID: nil do
        SamsonAwsSts.sts_client.must_equal nil
      end
    end
  end

  describe '#deploy_env_vars' do
    it 'returns a hash of additional env variables' do
      stage.aws_sts_iam_role_arn = "some_arn"
      vars = SamsonAwsSts.sts_client.deploy_env_vars(stage.deploys.last)
      vars.must_equal(
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
        duration_seconds: SamsonAwsSts::SESSION_DURATION_MIN
      )
      SamsonAwsSts.sts_client.assume_role(
        role_arn: 'arn',
        role_session_name: 'session',
        duration_seconds: SamsonAwsSts::SESSION_DURATION_MIN
      )
    end
  end

  describe '#caller_user_id' do
    it 'returns the user id' do
      SamsonAwsSts.sts_client.caller_user_id.must_equal 'userIdType'
    end
  end

  describe 'stage_permitted_params callback' do
    it 'returns attributes used by the plugin' do
      Samson::Hooks.only_callbacks_for_plugin('samson_aws_sts', :stage_permitted_params) do
        Samson::Hooks.fire(:stage_permitted_params).must_equal(
          [[:aws_sts_iam_role_arn, :aws_sts_iam_role_session_duration]]
        )
      end
    end
  end

  describe :deploy_execution_env do
    only_callbacks_for_plugin :deploy_execution_env

    it 'calls SamsonAwsSts.deploy_env_vars' do
      stage.aws_sts_iam_role_arn = "some_arn"
      SamsonAwsSts.expects(:sts_client).returns(Aws::STS::Client.new(stub_responses: true))
      Samson::Hooks.fire(:deploy_execution_env, stage.deploys.last).first.keys.must_include :STS_AWS_ACCESS_KEY_ID
    end

    it 'ignores when not active' do
      SamsonAwsSts.expects(:sts_client).never
      Samson::Hooks.fire(:deploy_execution_env, stage.deploys.last).must_equal [{}]
    end
  end
end

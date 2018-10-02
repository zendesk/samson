# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: 2

describe SamsonAwsSts do
  let(:stage) { stages(:test_staging) }

  describe '.set_env_vars' do
    it 'sets values against ENV' do
      %w(
        STS_AWS_ACCESS_KEY_ID 
        STS_AWS_SECRET_ACCESS_KEY
        STS_AWS_SESSION_TOKEN
      ).any? do |str|
        if ENV[str].present?
          raise "found ENV['#{str}'] has a value, please remove this to make the test run."
        end
      end

      stage.aws_sts_iam_role_arn = "some_arn"

      SamsonAwsSts.set_env_vars(
        sts_client: Aws::STS::Client.new(stub_responses: true),
        stage: stage
      )

      ENV['STS_AWS_ACCESS_KEY_ID'].must_equal 'accessKeyIdType'
      ENV['STS_AWS_SECRET_ACCESS_KEY'].must_equal 'accessKeySecretType'
      ENV['STS_AWS_SESSION_TOKEN'].must_equal 'tokenType'

      ENV.delete 'STS_AWS_ACCESS_KEY_ID'
      ENV.delete 'STS_AWS_SECRET_ACCESS_KEY'
      ENV.delete 'STS_AWS_SESSION_TOKEN'
    end
  end
end

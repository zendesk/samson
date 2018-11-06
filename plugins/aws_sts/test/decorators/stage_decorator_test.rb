# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Stage do
  let(:stage) { stages(:test_staging) }

  describe "validations" do
    it "is valid" do
      assert_valid stage
    end

    describe "ARN" do
      with_env SAMSON_STS_AWS_ACCESS_KEY_ID: 'x', SAMSON_STS_AWS_SECRET_ACCESS_KEY: 'y', SAMSON_STS_AWS_REGION: 'z'

      before do
        stage.aws_sts_iam_role_arn = "arn:aws:iam::1234:role/should_work"
      end

      it "is valid" do
        Aws::STS::Client.any_instance.expects(:assume_role).returns true
        assert_valid stage
      end

      it "is not valid with bad syntax" do
        Aws::STS::Client.any_instance.unstub(:assume_role)
        stage.aws_sts_iam_role_arn = "should_not_work"
        refute_valid stage
        stage.errors.full_messages.must_include(
          "Aws sts iam role arn Must be of the form: arn:aws:iam::ACCOUNT_ID:role/ROLE_NAME"
        )
      end

      it "is not valid when client cannot assume" do
        Aws::STS::Client.any_instance.expects(:assume_role).raises(RuntimeError)
        refute_valid stage
        stage.errors.full_messages.must_include(
          "Aws sts iam role arn Unable to assume role: RuntimeError"
        )
      end

      it "is not valid when env is not configured" do
        with_env SAMSON_STS_AWS_ACCESS_KEY_ID: nil do
          refute_valid stage
          stage.errors.full_messages.must_include(
            "Aws sts iam role arn SAMSON_STS_AWS_* env vars not set"
          )
        end
      end
    end

    describe "session duration" do
      before do
        stage.aws_sts_iam_role_session_duration = SamsonAwsSts::SESSION_DURATION_MIN
      end

      it "is valid" do
        assert_valid stage
      end

      it "is not valid when too short" do
        stage.aws_sts_iam_role_session_duration = SamsonAwsSts::SESSION_DURATION_MIN - 1
        refute_valid stage
        stage.errors.full_messages.must_equal [
          "Aws sts iam role session duration must be greater than or equal to 900"
        ]
      end

      it "is not valid when too long" do
        stage.aws_sts_iam_role_session_duration = SamsonAwsSts::SESSION_DURATION_MAX + 1
        refute_valid stage
        stage.errors.full_messages.must_equal [
          "Aws sts iam role session duration must be less than or equal to 7200"
        ]
      end
    end
  end
end

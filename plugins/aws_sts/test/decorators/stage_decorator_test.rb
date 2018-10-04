# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Stage do
  let(:stage) { stages(:test_staging) }

  describe "ARN syntax" do
    before do
      assert_valid stage
    end

    it "is not valid with bad syntax" do
      SamsonAwsSts.stubs(:sts_client).returns(Aws::STS::Client.new(stub_responses: true))

      stage.aws_sts_iam_role_arn = "should_not_work"
      refute_valid stage
      stage.errors.full_messages.must_include(
        "Aws sts iam role arn Must be of the form: arn:aws:iam::ACCOUNT_ID:role/ROLE_NAME"
      )
    end

    describe 'when client can assume role' do
      before do
        SamsonAwsSts::Client.any_instance.expects(:assume_role).returns true
      end

      it "is valid" do
        stage.aws_sts_iam_role_arn = "arn:aws:iam::1234:role/should_work"
        assert_valid stage
      end
    end

    describe 'when client can NOT assume role' do
      it "is NOT valid" do
        stage.aws_sts_iam_role_arn = "arn:aws:iam::1234:role/should_work"
        refute_valid stage
        stage.errors.full_messages.any? { |m| m =~ /Unable to assume role/ }.must_equal true
      end
    end
  end

  describe "session duration" do
    before do
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

    it "is valid when omitted" do
      stage.aws_sts_iam_role_session_duration = nil
      assert_valid stage
    end
  end

  describe 'before save' do
    it 'sets a default value for aws_sts_iam_role_session_duration' do
      stage.aws_sts_iam_role_session_duration = nil
      stage.save!
      stage.reload.aws_sts_iam_role_session_duration.must_equal SamsonAwsSts::SESSION_DURATION_MIN
    end
  end
end

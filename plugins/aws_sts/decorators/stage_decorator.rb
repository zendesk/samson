# frozen_string_literal: true
Stage.class_eval do
  validates(
    :aws_sts_iam_role_arn,
    allow_blank: true,
    format: {
      with: /\Aarn:aws:iam::\d+:role\/.+\Z/,
      message: "Must be of the form: arn:aws:iam::ACCOUNT_ID:role/ROLE_NAME"
    }
  )

  validates(
    :aws_sts_iam_role_session_duration,
    allow_blank: true,
    numericality: {
      only_integer: true,
      greater_than_or_equal_to: SamsonAwsSts::SESSION_DURATION_MIN,
      less_than_or_equal_to:    SamsonAwsSts::SESSION_DURATION_MAX
    }
  )

  validate :validate_can_assume_role, if: :aws_sts_iam_role_arn?

  private

  def validate_can_assume_role
    if client = SamsonAwsSts.sts_client
      begin
        client.assume_role(
          role_arn: aws_sts_iam_role_arn,
          role_session_name: "validate_can_assume_role_#{SecureRandom.hex(4)}",
          duration_seconds: SamsonAwsSts::SESSION_DURATION_MIN
        )
      rescue => e
        errors.add(:aws_sts_iam_role_arn, "Unable to assume role: #{e.message}")
      end
    else
      errors.add(:aws_sts_iam_role_arn, "SAMSON_STS_AWS_* env vars not set")
    end
  end
end

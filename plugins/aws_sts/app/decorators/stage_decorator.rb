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

  before_validation :set_default_session_duration
  validate :validate_can_assume_role, if: :aws_sts_iam_role_arn?

  private

  def set_default_session_duration
    self.aws_sts_iam_role_session_duration ||= SamsonAwsSts::SESSION_DURATION_MIN
  end

  def validate_can_assume_role
    SamsonAwsSts::Client.new(SamsonAwsSts.sts_client).assume_role(
      role_arn: aws_sts_iam_role_arn,
      role_session_name: "validate_can_assume_role_#{SecureRandom.hex(4)}"
    )
  rescue => e
    errors.add(:aws_sts_iam_role_arn, "Unable to assume role: #{e.message}")
  end
end

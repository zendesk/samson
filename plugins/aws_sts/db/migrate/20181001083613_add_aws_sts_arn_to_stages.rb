# frozen_string_literal: true

class AddAwsStsArnToStages < ActiveRecord::Migration[5.2]
  def change
    add_column :stages, :aws_sts_iam_role_arn, :string
    add_column :stages, :aws_sts_iam_role_session_duration, :integer, default: 900, null: false
  end
end

class AddAwsStsArnToStages < ActiveRecord::Migration[5.2]
  def change
    add_column :stages, :aws_sts_iam_role_arn, :string
  end
end

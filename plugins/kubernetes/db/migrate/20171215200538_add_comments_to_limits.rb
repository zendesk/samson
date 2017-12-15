# frozen_string_literal: true
class AddCommentsToLimits < ActiveRecord::Migration[5.1]
  def change
    add_column :kubernetes_usage_limits, :comment, :string, limit: 512
  end
end

# frozen_string_literal: true
class AddCommentToSecrets < ActiveRecord::Migration
  def change
    add_column :secrets, :comment, :string
  end
end

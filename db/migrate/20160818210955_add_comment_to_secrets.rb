# frozen_string_literal: true
class AddCommentToSecrets < ActiveRecord::Migration[4.2]
  def change
    add_column :secrets, :comment, :string
  end
end

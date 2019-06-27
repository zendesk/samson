# frozen_string_literal: true
class RemoveUserToken < ActiveRecord::Migration[5.2]
  def change
    remove_column :users, :token, :string
  end
end

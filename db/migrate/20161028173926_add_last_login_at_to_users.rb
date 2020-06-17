# frozen_string_literal: true
class AddLastLoginAtToUsers < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :last_login_at, :datetime
  end
end

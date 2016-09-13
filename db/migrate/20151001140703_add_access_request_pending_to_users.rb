# frozen_string_literal: true
class AddAccessRequestPendingToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :access_request_pending, :boolean, default: false
  end
end

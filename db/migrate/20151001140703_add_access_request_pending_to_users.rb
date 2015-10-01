class AddAccessRequestPendingToUsers < ActiveRecord::Migration
  def change
    add_column :users, :access_request_pending, :boolean, default: false
  end
end

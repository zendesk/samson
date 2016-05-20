class AddDesktopNotifyToUsers < ActiveRecord::Migration
  def change
    add_column :users, :desktop_notify, :boolean, default: false
  end
end

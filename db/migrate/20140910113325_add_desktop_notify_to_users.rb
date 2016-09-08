# frozen_string_literal: true
class AddDesktopNotifyToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :desktop_notify, :boolean, default: false
  end
end

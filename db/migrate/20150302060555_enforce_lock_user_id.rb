class EnforceLockUserId < ActiveRecord::Migration
  def change
    Lock.where(user_id: nil).update_all(user_id: User.where(role_id: 3).first.id) if User.where(role_id: 3).first
    change_column_null :locks, :user_id, false
  end
end

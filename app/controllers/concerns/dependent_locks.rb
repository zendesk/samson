module DependentLocks
  extend ActiveSupport::Concern

  included do
    after_action :remove_user_locks, only: [:destroy]
  end

  def remove_user_locks
    Lock.where(user: @user).map(&:soft_delete!)
  end
end

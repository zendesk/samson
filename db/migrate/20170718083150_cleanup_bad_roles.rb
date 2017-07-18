# frozen_string_literal: true
class CleanupBadRoles < ActiveRecord::Migration[5.1]
  class User < ActiveRecord::Base
  end

  class UserProjectRole < ActiveRecord::Base
  end

  def up
    existing_users = User.where(deleted_at: nil).pluck(:id)
    UserProjectRole.where.not(user_id: existing_users).delete_all
  end

  def down
  end
end

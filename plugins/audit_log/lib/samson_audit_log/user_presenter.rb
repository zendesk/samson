# frozen_string_literal: true

module SamsonAuditLog
  class UserPresenter
    ## User presenter for Audit Logger

    def self.present(user)
      {
        id: user.id,
        email: user.email,
        name: user.name,
        role: {
          id: user.role_id,
          name: user.role.try(:name)
        },
        created_at: user.created_at,
        updated_at: user.updated_at
      }
    end
  end
end

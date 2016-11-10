# frozen_string_literal: true

module SamsonAuditLog
  class UserProjectRolePresenter
    ## UserProjectRole presenter for Audit Logger

    def self.present(role)
      {
        id: role.id,
        user: SamsonAuditLog::AuditPresenter.present(role.user),
        project: SamsonAuditLog::AuditPresenter.present(role.project),
        role_id: role.role_id,
        role_name: role.role.try(:name),
        created_at: role.created_at,
        updated_at: role.updated_at
      }
    end
  end
end

# frozen_string_literal: true

module SamsonAuditLog
  class StagePresenter
    ## Stage presenter for Audit Logger

    def self.present(stage)
      {
        id: stage.id,
        name: stage.name,
        project: SamsonAuditLog::AuditPresenter.present(stage.project),
        no_code_deployed: stage.no_code_deployed,
        created_at: stage.created_at,
        updated_at: stage.updated_at
      }
    end
  end
end

# frozen_string_literal: true

module SamsonAuditLog
  class DeployPresenter
    ## Deploy presenter for Audit Logger

    def self.present(deploy)
      {
        id: deploy.id,
        stage: SamsonAuditLog::AuditPresenter.present(deploy.stage),
        reference: deploy.reference,
        deployer: SamsonAuditLog::AuditPresenter.present(deploy.job.try(:user)),
        buddy: SamsonAuditLog::AuditPresenter.present(deploy.buddy),
        started_at: deploy.started_at,
        created_at: deploy.created_at,
        updated_at: deploy.updated_at
      }
    end
  end
end

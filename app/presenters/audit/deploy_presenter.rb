# frozen_string_literal: true

class Audit::DeployPresenter
  ## Deploy presenter for Audit Logger
  ## Returns deploy object with only id, stage id and name, reference, deployer and buddy id and name, and time

  def self.present(deploy)
    if deploy
      {
        id: deploy.id,
        stage_id: deploy.stage_id,
        stage_name: deploy.stage.try(:name),
        reference: deploy.reference,
        deployer_id: deploy.job.user_id,
        deployer_name: deploy.job.user.name,
        buddy_id: deploy.buddy_id,
        buddy: deploy.buddy,
        created_at: deploy.created_at,
        updated_at: deploy.updated_at,
        started_at: deploy.started_at
      }
    end
  end
end

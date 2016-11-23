# frozen_string_literal: true

module SamsonAuditLog
  class DeployGroupPresenter
    ## DeployGroup presenter for Audit Logger

    def self.present(deploy_group)
      {
        id: deploy_group.id,
        permalink: deploy_group.permalink,
        name: deploy_group.name,
        environment: deploy_group.environment,
        created_at: deploy_group.created_at,
        updated_at: deploy_group.updated_at
      }
    end
  end
end

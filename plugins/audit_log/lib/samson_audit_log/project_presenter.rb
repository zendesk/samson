# frozen_string_literal: true

module SamsonAuditLog
  class ProjectPresenter
    ## Project presenter for Audit Logger

    def self.present(project)
      {
        id: project.id,
        permalink: project.permalink,
        name: project.name,
        created_at: project.created_at,
        updated_at: project.updated_at
      }
    end
  end
end

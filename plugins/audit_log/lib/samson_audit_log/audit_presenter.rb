# frozen_string_literal: true

module SamsonAuditLog
  class AuditPresenter
    ## Presenter for Audit Logger
    class << self
      AVAILABLE_PRESENTERS = [
        :deploy,
        :deploy_group,
        :project,
        :stage,
        :user,
        :user_project_role
      ].freeze

      def present(object)
        return unless object
        type = object.class.name.underscore.to_sym
        if AVAILABLE_PRESENTERS.include?(type)
          send(type, object)
        else
          object
        end
      end

      private

      def deploy(deploy)
        SamsonAuditLog::DeployPresenter.present(deploy)
      end

      def deploy_group(deploy_group)
        SamsonAuditLog::DeployGroupPresenter.present(deploy_group)
      end

      def project(project)
        SamsonAuditLog::ProjectPresenter.present(project)
      end

      def stage(stage)
        SamsonAuditLog::StagePresenter.present(stage)
      end

      def user(user)
        SamsonAuditLog::UserPresenter.present(user)
      end

      def user_project_role(role)
        SamsonAuditLog::UserProjectRolePresenter.present(role)
      end
    end
  end
end

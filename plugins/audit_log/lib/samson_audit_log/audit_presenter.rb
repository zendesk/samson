# frozen_string_literal: true

module SamsonAuditLog
  class AuditPresenter
    ## Presenter for Audit Logger
    class << self
      # Include object class names even if no special presenter and alias to original
      AVAILABLE_PRESENTERS = Set[
        :array,
        :deploy,
        :deploy_group,
        :project,
        :stage,
        :user,
        :user_project_role
      ]
      WHITE_LISTED_OBJECTS = Set[
        :environment,
        :fixnum,
        :hash,
        :"hashie/mash", # needed to pass SessionsController test
        :nil_class,
        :null_user, # needed to pass Deploy model test
        :"omni_auth/auth_hash", # this is received from the sessions controller on a failed or restricted auth attempt
        :string,
        :symbol
      ]

      def present(object)
        return unless object
        type = object.class.name.underscore.to_sym
        if AVAILABLE_PRESENTERS.include?(type)
          send(type, object)
        elsif WHITE_LISTED_OBJECTS.include?(type)
          object
        else
          raise ArgumentError
        end
      end

      private

      def array(array)
        array.map { |obj| present(obj) }
      end

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

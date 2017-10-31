# frozen_string_literal: true
class AccessControl
  class << self
    def can?(user, action, resource_namespace, scope = nil)
      case resource_namespace
      when 'access_tokens'
        case action
        when :write then user.super_admin? || user.id == scope&.resource_owner_id
        else raise ArgumentError, "Unsupported action #{action}"
        end
      when 'builds', 'webhooks'
        case action
        when :read then true
        when :write then user.deployer_for?(scope)
        else raise ArgumentError, "Unsupported action #{action}"
        end
      when 'locks'
        case action
        when :read then true
        when :write
          if scope
            user.deployer_for?(scope) # stage locks
          else
            user.admin? # global locks
          end
        else raise ArgumentError, "Unsupported action #{action}"
        end
      when 'projects', 'build_commands', 'stages', 'user_project_roles'
        case action
        when :read then true
        when :write then user.admin_for?(scope)
        else raise ArgumentError, "Unsupported action #{action}"
        end
      when 'users'
        case action
        when :read then user.admin?
        when :write then user.super_admin?
        else raise ArgumentError, "Unsupported action #{action}"
        end
      when 'secrets'
        case action
        when :read then can_deploy_anything?(user)
        when :write then user.admin_for?(scope)
        else raise ArgumentError, "Unsupported action #{action}"
        end
      when 'user_merges', 'vault_servers', 'environments'
        case action
        when :read then true
        when :write then user.super_admin?
        else raise ArgumentError, "Unsupported action #{action}"
        end
      else
        raise ArgumentError, "Unsupported resource_namespace #{resource_namespace}"
      end
    end

    private

    def can_deploy_anything?(user)
      user.deployer? || user.user_project_roles.where('role_id >= ?', Role::DEPLOYER.id).exists?
    end
  end
end

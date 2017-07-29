# frozen_string_literal: true
class AccessControl
  class << self
    def can?(user, action, resource, project = nil)
      case resource
      when 'builds', 'webhooks'
        case action
        when :read then true
        when :write then user.deployer_for?(project)
        else raise ArgumentError, "Unsupported action #{action}"
        end
      when 'locks'
        case action
        when :read then true
        when :write
          if project
            user.deployer_for?(project) # stage locks
          else
            user.admin? # global locks
          end
        else raise ArgumentError, "Unsupported action #{action}"
        end
      when 'projects', 'build_commands', 'stages', 'user_project_roles'
        case action
        when :read then true
        when :write then user.admin_for?(project)
        else raise ArgumentError, "Unsupported action #{action}"
        end
      when 'users'
        case action
        when :read then user.admin?
        when :write then user.super_admin?
        else raise ArgumentError, "Unsupported action #{action}"
        end
      when 'users_search'
        case action
        when :read then user.super_admin?
        else raise ArgumentError, "Unsupported action #{action}"
        end
      when 'secrets'
        case action
        when :read then can_deploy_anything?(user)
        when :write then user.admin_for?(project)
        else raise ArgumentError, "Unsupported action #{action}"
        end
      when 'user_merges', 'vault_servers', 'environments'
        case action
        when :read then true
        when :write then user.super_admin?
        else raise ArgumentError, "Unsupported action #{action}"
        end
      else
        raise ArgumentError, "Unsupported resource #{resource}"
      end
    end

    private

    def can_deploy_anything?(user)
      user.deployer? || user.user_project_roles.where('role_id >= ?', Role::DEPLOYER.id).exists?
    end
  end
end

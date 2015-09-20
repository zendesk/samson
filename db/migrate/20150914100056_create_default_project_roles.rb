class CreateDefaultProjectRoles < ActiveRecord::Migration
  def change

    #Creating default project role relations for non Viewers
    User.where.not(role_id: Role::VIEWER.id).each { |user|
      Project.find_each { |project|

        if !UserProjectRole.exists?(project: project, user: user)
          if user.role_id == Role::ADMIN.id
            UserProjectRole.create!(project: project, user: user, role_id: ProjectRole::ADMIN.id)
          elsif user.role_id == Role::DEPLOYER.id
            UserProjectRole.create!(project: project, user: user, role_id: ProjectRole::DEPLOYER.id)
          end
        end
      }
    }

  end
end

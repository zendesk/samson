class CreateDefaultProjectRoles < ActiveRecord::Migration
  def change

    #Creating default project role relations for non Viewers
    User.where.not(role_id: Role::VIEWER.id).each { |user|
      Project.find_each { |project|

        if !UserProjectRole.exists?(project: project, user: user)
          if user.role_id == 2 || user.role_id == 3 #super admin or admin
            UserProjectRole.create!(project: project, user: user, role_id: ProjectRole::ADMIN.id)
          elsif user.role_id == 1 #deployer
            UserProjectRole.create!(project: project, user: user, role_id: ProjectRole::DEPLOYER.id)
          end
        end
      }
    }

  end
end

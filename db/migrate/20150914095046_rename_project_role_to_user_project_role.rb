class RenameProjectRoleToUserProjectRole < ActiveRecord::Migration
  def change
    rename_table :project_roles, :user_project_roles
  end
end

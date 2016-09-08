# frozen_string_literal: true
class UniqueRoles < ActiveRecord::Migration[4.2]
  class UserProjectRole < ActiveRecord::Base
  end

  def up
    # delete the lowest permission duplicate roles
    UserProjectRole.all.group_by { |role| [role.user_id, role.project_id] }.each do |_, roles|
      roles.sort_by(&:role_id)[0..-2].each(&:destroy)
    end

    add_index :user_project_roles, [:user_id, :project_id], unique: true
    remove_index :user_project_roles, :user_id
  end

  def down
    add_index :user_project_roles, :user_id
    remove_index :user_project_roles, [:user_id, :project_id]
  end
end

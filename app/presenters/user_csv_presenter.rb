# frozen_string_literal: true
require 'csv'

class UserCsvPresenter
  ## Returns a CSV output of the user's permissions report
  ## Params
  ## - Options hash:
  ##   - inherited - defaults to false, each user will show a value for each project even without a UserProjectRole
  ##       This value is set to true when reporting on a specific user or project
  ##   - deleted - defaults to false, removes the soft_deletion scope from users, and will display deleted users
  ##   - project_id - defaults to nil, reports on only one project (will set inherited to true)
  ##   - user_id - defaults to nil, reports on only one user (will set inherited to true)
  ##   - datetime - defaults to now, Timestamp for when the report is kicked off and generated

  def self.to_csv(
    inherited: false, deleted: false, project_id: nil, user_id: nil, datetime: (Time.now.strftime "%Y%m%d_%H%M")
  )
    inherited = true if project_id || user_id
    users = (deleted || user_id ? User.unscoped : User)
    users = users.order(:id)
    users = users.where(id: user_id) if user_id
    if inherited
      permissions_projects = project_id ? Project.where(id: project_id) : Project
      total = project_id ? users.count : (1 + permissions_projects.count) * users.count
    else
      total = users.count + UserProjectRole.joins(:user, :project).count
    end
    summary = ["-", "Generated At", datetime, "Users", users.count.to_s, "Total entries", total.to_s]
    options_applied = [
      "-", "Options",
      {
        inherited: inherited,
        deleted: deleted,
        project_id: project_id,
        user_id: user_id
      }.to_json
    ]

    CSV.generate do |csv|
      csv << csv_header
      users.each do |user|
        csv << csv_line(user, nil, nil) unless project_id

        # Grab all of the user's project roles for active projects
        project_roles = user.user_project_roles.joins(:project)
        if inherited
          # manually precache each of the user_project_roles to avoid Rails querying user_project_roles
          # when no user project role exists for the user project combination
          user_roles = project_roles.pluck(:project_id, :role_id).to_h

          permissions_projects.find_each { |project| csv << csv_line(user, project, user_roles[project.id]) }
        else
          project_roles.each do |user_project_role|
            csv << csv_line(user, user_project_role.project, user_project_role.role_id)
          end
        end
      end
      csv << summary
      csv << options_applied
    end
  end

  def self.csv_header
    ["id", "name", "email", "projectiD", "project", "role", "deleted at"]
  end

  ## Returns csv line for CSV Report
  ## Params
  ## - user: User Object
  ## - project: Project object or nil for System level role
  ## - project_role_id: prefetched user_project_role for project
  ## - project_role_id is prefetched inside of to_csv to optimize to O(N) from O(N*M) using native
  ##   ActiveRecord methods

  def self.csv_line(user, project, project_role_id)
    [
      user.id,
      user.name,
      user.email,
      project ? project.id : "",
      project ? project.name : "SYSTEM",
      (project && project_role_id) ? effective_project_role(user, project_role_id) : user.role.name,
      user.deleted_at
    ]
  end

  ## Returns effective project role name
  ## Params
  ## - user: User Object
  ## - project_role_id: project_role_id or nil
  ## Does not make a call to UserProjectRoles for optimization

  def self.effective_project_role(user, project_role_id)
    if user.role_id == Role::SUPER_ADMIN.id || user.role_id == Role::ADMIN.id
      Role::ADMIN.name
    else
      user.role_id.to_i >= project_role_id.to_i ? user.role.name : Role.find(project_role_id).name
    end
  end
end

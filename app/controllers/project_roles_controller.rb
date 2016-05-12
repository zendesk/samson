class ProjectRolesController < ApplicationController
  include CurrentProject

  before_action :authorize_project_admin!

  def create
    user = User.find(params[:user_id])
    role = UserProjectRole.where(user: user, project: current_project).first_or_initialize
    role.role_id = params[:role_id].presence

    if role.role_id
      role.save!
      user.update!(access_request_pending: false)
    elsif role.persisted?
      role.destroy!
    end

    role_name = (role.role.try(:display_name) || 'None')
    Rails.logger.info(
      "#{current_user.name_and_email} set the role #{role_name} to #{user.name}} on project #{current_project.name}"
    )

    render plain: "Saved!"
  end
end

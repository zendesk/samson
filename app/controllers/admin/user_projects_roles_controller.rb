class Admin::UserProjectsRolesController < ApplicationController
  before_action :authorize_super_admin!

  def create
    new_role = user.user_project_roles.create(create_params)

    if new_role.persisted?
      Rails.logger.info("#{current_user.name_and_email} granted the role of #{project_role_name} to #{user.name} on project ID #{project_id}")
      render status: :created, json: {project_role: new_role}
    else
      render text: "Error: could not assign role '#{project_role_name}' to project ID #{project_id}", status: :bad_request
    end
  end

  def update
    if project_role.update_attributes(update_params)
      Rails.logger.info("#{current_user.name_and_email} granted the role of #{project_role_name} to #{user.name} on project ID #{project_id}")
      render status: :ok, json: {project_role: project_role}
    else
      render status: :bad_request, text: "Error: could not assign role '#{project_role_name}' to project ID #{project_id}"
    end
  end

  private

  def project_role_name
    ProjectRole.find(new_role_id).display_name
  end

  def new_role_id
    params[:project_role][:role_id]
  end

  def project_id
    params[:project_role][:project_id]
  end

  def user
    @user ||= User.find(params[:user_id])
  end

  def project_role
    @project_role ||= UserProjectRole.find(params[:id])
  end

  def create_params
    params.require(:project_role).permit(:user_id, :project_id, :role_id)
  end

  def update_params
    params.require(:project_role).permit(:role_id)
  end
end

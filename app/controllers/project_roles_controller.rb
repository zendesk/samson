class ProjectRolesController < ApplicationController
  include CurrentProject
  include ProjectLevelAuthorization

  before_action only: [:create, :update] do
    find_project(params[:project_id])
  end

  before_action :authorize_project_admin!, only: [:create, :update]

  def index
    render json: ProjectRole.all.map { |role| { id: role.id, display_name: role.display_name } }, root: false
  end

  def create
    new_role = UserProjectRole.create(create_params)

    if new_role.persisted?
      user = User.find(create_params[:user_id])
      Rails.logger.info("#{current_user.name_and_email} granted the role of #{project_role_name} to #{user.name} on project #{current_project.name}")
      render status: :created, json: {project_role: new_role}
    else
      render status: :bad_request, json: { errors: new_role.errors.full_messages }
    end
  end

  def update
    project_role = UserProjectRole.update_user_role(params[:id], update_params)

    if project_role.errors.empty?
      user = User.find(project_role.user_id)
      Rails.logger.info("#{current_user.name_and_email} granted the role of #{project_role_name} to #{user.name} on project #{current_project.name}")
      render status: :ok, json: {project_role: project_role}
    else
      render status: :bad_request, json: { errors: project_role.errors.full_messages }
    end
  end

  private

  def project_role_name
    ProjectRole.find(params[:project_role][:role_id]).display_name
  end

  def create_params
    params.require(:project_role).permit(:user_id, :project_id, :role_id)
  end

  def update_params
    params.require(:project_role).permit(:role_id)
  end
end

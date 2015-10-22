class ProjectRolesController < ApplicationController
  include ProjectLevelAuthorization

  skip_before_action :require_project, only: [:index]

  before_action :authorize_project_admin!, only: [:create, :update]

  def index
    render json: ProjectRole.all, root: false
  end

  def create
    new_role = UserProjectRole.create(create_params)

    if new_role.persisted?
      Rails.logger.info("#{current_user.name_and_email} granted the role of #{new_role.role.display_name} to #{new_role.user.name} on project #{current_project.name}")
      reset_access_request_flag(new_role.user)
      render status: :created, json: new_role
    else
      render status: :bad_request, json: {errors: new_role.errors.full_messages}
    end
  end

  def update
    project_role = UserProjectRole.find(params[:id])
    if project_role.update(update_params)
      Rails.logger.info("#{current_user.name_and_email} granted the role of #{project_role.role.display_name} to #{project_role.user.name} on project #{current_project.name}")
      reset_access_request_flag(project_role.user)
      render status: :ok, json: project_role
    else
      render status: :bad_request, json: {errors: project_role.errors.full_messages}
    end
  end

  private

  def create_params
    params.require(:project_role).permit(:user_id, :project_id, :role_id)
  end

  def update_params
    params.require(:project_role).permit(:role_id)
  end

  def reset_access_request_flag(user)
    user.update!(access_request_pending: false)
  end
end

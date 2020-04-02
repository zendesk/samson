# frozen_string_literal: true
class EnvironmentVariableGroupsController < ApplicationController
  before_action :authorize_user!, except: [:index, :show, :preview]
  before_action :group, only: [:show]

  def index
    @groups = EnvironmentVariableGroup.all.includes(:environment_variables)

    if project_id = params[:project_id].presence
      @groups = @groups.joins(:project_environment_variable_groups).
        where("project_environment_variable_groups.project_id = ?", project_id)
    end

    respond_to do |format|
      format.html
      format.json do
        render_as_json :environment_variable_groups, @groups, nil, allowed_includes: [
          :environment_variables,
        ]
      end
    end
  end

  def new
    render 'form'
  end

  def create
    group.attributes = attributes
    if group.save
      redirect_to action: :index
    else
      render 'form'
    end
  end

  def show
    render 'form'
  end

  def update
    if group.update(attributes)
      redirect_to action: :index
    else
      render 'form'
    end
  end

  def destroy
    group.destroy!
    redirect_to action: :index
  end

  def preview
    deploy_groups =
      if deploy_group = params[:deploy_group].presence
        [DeployGroup.find_by_permalink!(deploy_group)]
      else
        DeployGroup.all
      end

    if group_id = params[:group_id]
      @group = EnvironmentVariableGroup.find(group_id)
      @project = Project.new(environment_variable_groups: [@group])
    else
      @project = Project.find(params[:project_id])
    end

    secrets = (params[:preview].to_s == "false" ? false : :preview)

    @groups = SamsonEnv.env_groups(
      Deploy.new(project: @project),
      deploy_groups,
      project_specific: params[:project_specific],
      resolve_secrets: secrets
    )

    respond_to do |format|
      format.html
      format.json { render json: {groups: @groups || []} }
    end
  end

  private

  def group
    @group ||= if ['new', 'create'].include?(action_name)
      EnvironmentVariableGroup.new
    else
      EnvironmentVariableGroup.find(params[:id])
    end
  end

  def attributes
    params.require(:environment_variable_group).permit(
      :name,
      :comment,
      :owners,
      :external_url,
      AcceptsEnvironmentVariables::ASSIGNABLE_ATTRIBUTES
    )
  end

  def authorize_user!
    unauthorized! unless can? :write, :environment_variable_groups, group
  end
end

# frozen_string_literal: true
class EnvironmentVariableGroupsController < ApplicationController
  before_action :authorize_user!, except: [:index, :show, :preview]
  before_action :group, only: [:show]

  # poor mans access_control.rb `can?` replacement
  def self.write?(user, group)
    return true if user.admin?

    administrated = user.administrated_projects.pluck(:id)
    return true if administrated.any? && group.projects.pluck(:id).all? { |id| administrated.include?(id) }

    false
  end

  def index
    @groups = EnvironmentVariableGroup.all
  end

  def new
    render 'form'
  end

  def create
    group.attributes = attributes
    group.save!
    redirect_to action: :index
  end

  def show
    render 'form'
  end

  def update
    group.update_attributes!(attributes)
    redirect_to action: :index
  end

  def destroy
    group.destroy!
    redirect_to action: :index
  end

  def preview
    @deploy_group = DeployGroup.all
    @deploy_group = @deploy_group.where(permalink: params[:scope]) if params[:scope].present?

    if params[:group_id]
      @group = EnvironmentVariableGroup.find(params[:group_id])
      @project = Project.new(environment_variable_groups: [@group])
    else
      @project = Project.find(params[:project_id])
    end

    @groups = SamsonEnv.env_groups(@project, @deploy_group, preview: true)

    respond_to do |format|
      format.html
      format.json { render json: { groups: @groups || [] } }
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
      AcceptsEnvironmentVariables::ASSIGNABLE_ATTRIBUTES
    )
  end

  def authorize_user!
    unauthorized! unless self.class.write?(current_user, group)
  end
end

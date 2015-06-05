module Admin
  class EnvironmentVariableGroupsController < ApplicationController
    before_action :authorize_admin!, except: [:index, :show, :preview]
    before_action :group, only: [:show]

    def index
      @groups = EnvironmentVariableGroup.all
    end

    def new
      @group = EnvironmentVariableGroup.new
      render 'form'
    end

    def create
      EnvironmentVariableGroup.create!(attributes)
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
      @groups = if params[:group_id]
        @group = EnvironmentVariableGroup.find(params[:group_id])
        SamsonEnv.env_groups(Stage.new(environment_variable_groups: [@group], deploy_groups: DeployGroup.all))
      else
        @stage = Stage.find(params[:stage_id])
        SamsonEnv.env_groups(@stage)
      end
    end

    private

    def group
      @group ||= EnvironmentVariableGroup.find(params[:id])
    end

    def attributes
      params.require(:environment_variable_group).permit(
        :name,
        :comment,
        AcceptsEnvironmentVariables::ASSIGNABLE_ATTRIBUTES
      )
    end
  end
end

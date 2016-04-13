class MacrosController < ApplicationController
  include ProjectLevelAuthorization

  before_action :authorize_project_deployer!
  before_action :authorize_project_admin!, only: [:new, :create, :edit, :update]
  before_action :authorize_super_admin!, only: [:destroy]
  before_action :find_macro, only: [:show, :edit, :update, :execute, :destroy]

  def index
    @macros = @project.macros.page(params[:page])
  end

  def show
    @stage = @macro
    @deploys = @macro.deploys.page(params[:page])
  end

  def new
    @macro = @project.macros.build
  end

  def create
    @macro = @project.macros.build(macro_params)

    if @macro.save
      redirect_to project_macros_path(@project)
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @macro.update_attributes(macro_params)
      redirect_to project_macros_path(@project)
    else
      flash[:error] = @macro.errors.full_messages
      render :edit
    end
  end

  def destroy
    @macro.soft_delete!
    redirect_to project_macros_path(@project)
  end

  private

  def macro_params
    params.require(:macro).permit(
      :name, :command, :permalink,
      command_ids: [],
      deploy_group_ids: []
    )
  end

  def command_params
    params.require(:commands).permit(ids: [])
  end

  def find_macro
    @macro = @project.macros.find_by_param!(params[:id])
  end
end

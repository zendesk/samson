class Kubernetes::TasksController < ApplicationController
  include CurrentProject

  DEPLOYER_ACCESS = [:index, :show].freeze
  before_action :authorize_project_deployer!, only: DEPLOYER_ACCESS
  before_action :authorize_project_admin!, except: DEPLOYER_ACCESS
  before_action :find_task, only: [:show, :update, :run, :destroy]

  def index
    @tasks = ::Kubernetes::Task.not_deleted.where(project: current_project).order('name desc')
  end

  def seed
    Kubernetes::Task.seed!(@project, params.require(:ref))
    redirect_to action: :index
  end

  def new
    @task = Kubernetes::Task.new
  end

  def create
    @task = Kubernetes::Task.new(task_params.merge(project: @project))
    if @task.save
      redirect_to action: :index
    else
      render :new
    end
  end

  def show
  end

  def update
    if @task.update_attributes(task_params)
      redirect_to action: :index
    else
      render :show
    end
  end

  def destroy
    @task.soft_delete!
    redirect_to action: :index
  end

  private

  def find_task
    @task = Kubernetes::Task.not_deleted.find(params[:id])
  end

  def task_params
    params.require(:kubernetes_task).permit(:name, :config_file)
  end
end

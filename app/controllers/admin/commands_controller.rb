class Admin::CommandsController < ApplicationController
  before_filter :authorize_admin!

  rescue_from ActiveRecord::RecordNotFound do
    redirect_to admin_commands_path
  end

  def index
    @commands = Command.order('project_id').page(params[:page])
  end

  def new
    @command = Command.new
  end

  def create
    @command = Command.create(command_params)

    if @command.persisted?
      flash[:notice] = 'Command created.'
      redirect_to admin_commands_path
    else
      flash[:error] = 'Command failure.'
      render :new
    end
  end

  def edit
    @command = Command.find(params[:id])
  end

  def update
    @command = Command.find(params[:id])

    if @command.update_attributes(command_params)
      respond_to do |format|
        format.html do
          flash[:notice] = 'Command updated.'
          redirect_to admin_commands_path
        end

        format.json { render json: {} }
      end
    else
      respond_to do |format|
        format.html do
          flash[:error] = 'Command failure.'
          render :edit
        end

        format.json { render json: {}, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    Command.destroy(params[:id])

    respond_to do |format|
      format.html do
        flash[:notice] = 'Command removed.'
        redirect_to admin_commands_path
      end

      format.json { render json: {} }
    end
  end

  private

  def command_params
    params.require(:command).permit(:command, :project_id)
  end
end

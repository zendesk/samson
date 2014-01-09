class Admin::CommandsController < ApplicationController
  before_filter :authorize_admin!

  rescue_from ActiveRecord::RecordNotFound do
    redirect_to admin_commands_path
  end

  def index
    @commands = Command.all
  end

  def new
    @command = Command.new
  end

  def create
    @command = current_user.commands.create(command_params)

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
      flash[:notice] = 'Command updated.'
      redirect_to admin_commands_path
    else
      flash[:error] = 'Command failure.'
      render :edit
    end
  end

  def destroy
    Command.destroy(params[:id])

    flash[:notice] = 'Command removed.'
    redirect_to admin_commands_path
  end

  private

  def command_params
    params.require(:command).
      permit(:name, :command)
  end
end

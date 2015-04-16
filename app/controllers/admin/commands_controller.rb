class Admin::CommandsController < ApplicationController
  load_and_authorize_resource class: Command
  skip_load_resource only: :index

  def index
    @commands = Command.order('project_id').page(params[:page])
  end

  def new
  end

  def create
    @command.save

    if @command.persisted?
      flash[:notice] = 'Command created.'
      redirect_to admin_commands_path
    else
      flash[:error] = 'Command failure.'
      render :new
    end
  end

  def edit
  end

  def update
    if @command.update_attributes(command_params)
      successful_response('Command updated.')
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
    @command.destroy

    successful_response('Command removed.')
  end

  private

  def command_params
    params.require(:command).permit(:command, :project_id)
  end

  def successful_response(notice)
    respond_to do |format|
      format.html do
        flash[:notice] = notice
        redirect_to admin_commands_path
      end

      format.json { render json: {} }
    end
  end
end

class Admin::CommandsController < ApplicationController
  include SamsonAudit

  before_action :authorize_admin!

  #Audit
  before_action only: :update do
    prepare_audit(command)
  end
  after_action only: [:create, :destroy, :update] do
    audit(command)
  end

  def index
    @commands = Command.order('project_id').page(params[:page])
  end

  def new
    @command = Command.new
    render :edit
  end

  def create
    @command = Command.create(command_params)

    if @command.persisted?
      flash[:notice] = 'Command created.'
      redirect_to admin_commands_path
    else
      flash[:error] = 'Command failure.'
      render :edit
    end
  end

  def edit
    @command = Command.find(params[:id])
  end

  def update

    if command.update_attributes(command_params)
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
    command.destroy
    successful_response('Command removed.')
  end

  private

  def command
    @command ||= Command.find(params[:id])
  end

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

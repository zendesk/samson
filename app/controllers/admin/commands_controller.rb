# frozen_string_literal: true
class Admin::CommandsController < ApplicationController
  include CurrentProject

  before_action :find_command, only: [:update, :show]
  before_action :authorize_project_admin!, only: [:update, :show]
  before_action :authorize_admin!, except: [:update, :show]

  def index
    @commands = Command.order(:project_id).page(params[:page])
    if search = params[:search]
      if query = search[:query].presence
        query = ActiveRecord::Base.send(:sanitize_sql_like, query)
        @commands = @commands.where('command like ?', "%#{query}%")
      end

      if project_id = search[:project_id].presence
        project_id = nil if project_id == 'global'
        @commands = @commands.where(project_id: project_id)
      end
    end
  end

  def new
    @command = Command.new
    render :show
  end

  def create
    @command = Command.create(command_params)

    if @command.persisted?
      successful_response 'Command created.'
    else
      render :show
    end
  end

  def show
  end

  def update
    if @command.update_attributes(command_params)
      successful_response('Command updated.')
    else
      respond_to do |format|
        format.html { render :show }
        format.json { render json: {}, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    Command.destroy(params[:id])
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

  def find_command
    @command = Command.find(params[:id])
  end

  def current_project
    @command.project
  end
end

# frozen_string_literal: true
class Admin::CommandsController < ApplicationController
  include CurrentProject

  PUBLIC = [:index, :show, :new].freeze

  before_action :find_command, only: [:update, :show, :destroy]
  before_action :authorize_custom_project_admin!, except: PUBLIC

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

  def find_command
    @command = Command.find(params[:id])
  end

  def authorize_custom_project_admin!
    projects =
      if action_name == 'create'
        [project_from_params]
      elsif action_name == 'update'
        [project_from_params, @command.project]
      else
        [@command.project]
      end

    projects.each do |project|
      unauthorized! unless current_user.admin_for?(project)
    end
  end

  def project_from_params
    if id = command_params[:project_id].presence
      Project.find(id)
    end
  end
end

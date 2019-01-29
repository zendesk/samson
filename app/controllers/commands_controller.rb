# frozen_string_literal: true
class CommandsController < ApplicationController
  include CurrentProject

  PUBLIC = [:index, :show, :new].freeze

  before_action :find_command, only: [:update, :show, :destroy]
  before_action :authorize_custom_project_admin!, except: PUBLIC

  def index
    @commands = Command.order(:project_id)
    if search = params[:search]
      if query = search[:query].presence
        query = ActiveRecord::Base.send(:sanitize_sql_like, query)
        @commands = @commands.where(Command.arel_table[:command].matches("%#{query}%"))
      end

      if project_id = search[:project_id].presence
        project_id = nil if project_id == 'global'
        @commands = @commands.where(project_id: project_id)
      end
    end
    @pagy, @commands = pagy(@commands, page: page, items: 15)
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
    # Destroy specific stage command usage if `stage_id` is passed in to allow for inline deletion
    remove_stage_usage_if_exists

    if @command.destroy
      successful_response('Command removed.')
    else
      respond_to do |format|
        format.html { render :show }
        format.json { render json: {}, status: :unprocessable_entity }
      end
    end
  end

  private

  def command_params
    params.require(:command).permit(:command, :project_id)
  end

  def successful_response(notice)
    respond_to do |format|
      format.html do
        flash[:notice] = notice
        redirect_to @command
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
        projects = [@command.project]
        projects << project_from_params if command_params.key?(:project_id) # when moving, need to be able to write both
        projects
      else
        [@command.project]
      end

    projects.each do |project|
      unauthorized! unless can? :write, :projects, project
    end
  end

  def project_from_params
    if id = command_params[:project_id].presence
      Project.find(id)
    end
  end

  def remove_stage_usage_if_exists
    return if params[:stage_id].nil?
    StageCommand.find_by(stage_id: params[:stage_id], command_id: @command.id)&.destroy
  end
end

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

    multi_format_render(
      successful: true,
      on_success_html: -> { @pagy, @commands = pagy(@commands, page: page, items: 15) },
      on_success_json: -> {
        @pagy, @commands = pagy(@commands, page: page, items: 50)
        render_as_json :commands, @commands
      }
    )
  end

  def new
    @command = Command.new
    render :show
  end

  def create
    @command = Command.create(command_params)
    is_saved = @command.persisted?
    render_formats(is_saved)
  end

  def show
    multi_format_render(
      successful: true,
      on_success_html: -> {},
      on_success_json: -> { render_as_json :command, @command }
    )
  end

  def update
    is_saved = @command.update_attributes(command_params)
    render_formats(is_saved)
  end

  def destroy
    # Destroy specific stage command usage if `stage_id` is passed in to allow for inline deletion
    remove_stage_usage_if_exists
    is_destroyed = @command.destroy
    render_formats(is_destroyed)
  end

  private

  def command_params
    params.require(:command).permit(:command, :project_id)
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

  def render_formats(successful)
    multi_format_render(
      successful: successful,
      on_success_html: -> {
        flash[:notice] = 'Command created.'
        redirect_to commands_path
      },
      on_error_html: -> { render :show },
      on_success_json: -> { render_as_json :command, @command },
      on_error_json: -> { render_json_error 422, @command.errors },
      on_success_js: -> { render json: {} },
      on_error_js: -> { render_json_error 422, @command.errors }
    )
  end
end

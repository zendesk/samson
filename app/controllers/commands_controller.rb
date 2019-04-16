# frozen_string_literal: true
class CommandsController < ResourceController
  include CurrentProject

  PUBLIC = [:index, :show, :new].freeze

  before_action :set_resource, only: [:show, :edit, :update, :destroy, :new, :create]
  before_action :authorize_custom_project_admin!, except: PUBLIC

  def destroy
    remove_stage_usage_if_exists
    super
  end

  private

  def search_resources
    commands = Command.order(:project_id)
    if search = params[:search]
      if query = search[:query].presence
        query = ActiveRecord::Base.send(:sanitize_sql_like, query)
        commands = commands.where(Command.arel_table[:command].matches("%#{query}%"))
      end

      if project_id = search[:project_id].presence
        project_id = nil if project_id == 'global'
        commands = commands.where(project_id: project_id)
      end
    end
    commands
  end

  def resource_params
    super.permit(:command, :project_id)
  end

  def authorize_custom_project_admin!
    projects =
      if action_name == 'create'
        [project_from_params]
      elsif action_name == 'update'
        projects = [@command.project]
        projects << project_from_params if resource_params.key?(:project_id) # moving: need to be able to write both
        projects
      else
        [@command.project]
      end

    projects.each do |project|
      unauthorized! unless can? :write, :projects, project
    end
  end

  def project_from_params
    if id = resource_params[:project_id].presence
      Project.find(id)
    end
  end

  # Destroy specific stage command usage if `stage_id` is passed in to allow for inline deletion
  def remove_stage_usage_if_exists
    return if params[:stage_id].nil?
    StageCommand.find_by(stage_id: params[:stage_id], command_id: @command.id)&.destroy
  end
end

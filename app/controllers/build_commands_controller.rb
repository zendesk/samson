# frozen_string_literal: true
class BuildCommandsController < ApplicationController
  include CurrentProject

  before_action :authorize_resource!
  before_action :find_command

  def show
  end

  def update
    command = params[:command][:command]
    if command.blank?
      current_project.update(build_command: nil)
      @command.projects.reload
      @command.destroy!
    else
      @command.command = command
      @command.project = @project
      @command.save!
      @project.update_column(:build_command_id, @command.id) unless @project.build_command_id
    end
    redirect_to project_builds_path(@project), notice: 'Build command updated!'
  end

  private

  def find_command
    @command = current_project.build_command || current_project.build_build_command(project: @project)
  end
end

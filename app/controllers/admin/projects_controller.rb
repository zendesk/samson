# frozen_string_literal: true
class Admin::ProjectsController < ApplicationController
  before_action :authorize_admin!

  def index
    @projects = Project.page(params[:page])
    if query = params.dig(:search, :query).presence
      query = ActiveRecord::Base.send(:sanitize_sql_like, query)
      @projects = @projects.where('name like ?', "%#{query}%")
    end
  end

  def destroy
    project = Project.find_by_permalink!(params[:id])
    project.soft_delete(validate: false)

    if Rails.application.config.samson.project_deleted_email
      ProjectMailer.deleted_email(@current_user, project).deliver_later
    end
    flash[:notice] = "Project removed."
    redirect_to admin_projects_path
  end
end

# frozen_string_literal: true
class CsvExportsController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound do |exception|
    respond_to do |format|
      format.json { render json: {status: "not found"}.to_json, status: :not_found }
      format.csv  { render body: "not found", status: :not_found }
      format.html { raise exception }
    end
  end

  def index
    @csv_exports = CsvExport.where(user_id: current_user.id)
    respond_to do |format|
      format.html
      format.json { render json: {csv_exports: @csv_exports} }
    end
  end

  def new
    respond_to do |format|
      format.html do
        case params[:type]
        when "users"
          render :new_users
        when "deploy_group_usage"
          render :new_deploy_group_usage
        else
          @csv_export = CsvExport.new
        end
      end
      format.csv do
        case params[:type]
        when "users"
          options = user_filter
          send_data UserCsvPresenter.to_csv(**options), type: :csv, filename: "Users_#{options[:datetime]}.csv"
        when "deploy_group_usage"
          date_time_now = Time.now.strftime "%Y%m%d_%H%M"
          send_data DeployGroupUsageCsvPresenter.to_csv, type: :csv, filename: "DeployGroupUsage_#{date_time_now}.csv"
        else
          render body: "not found", status: :not_found
        end
      end
    end
  end

  def show
    @csv_export = CsvExport.find(params[:id])
    respond_to do |format|
      format.html
      format.json { render json: @csv_export }
      format.csv { download }
    end
  end

  def create
    filters = deploy_filter
    csv_export = CsvExport.create!(user: current_user, filters: filters)
    JobQueue.perform_later CsvExportJob.new(csv_export)
    redirect_to csv_export
  end

  private

  def download
    if @csv_export.status? :ready
      begin
        send_file @csv_export.path_file, type: :csv, filename: @csv_export.download_name
        @csv_export.status! :downloaded
        Rails.logger.info("#{current_user.name_and_email} just downloaded #{@csv_export.download_name})")
      rescue ActionController::MissingFile
        @csv_export.status! :deleted
        redirect_to @csv_export
      end
    else
      redirect_to @csv_export
    end
  end

  def user_filter
    options = {}
    options[:inherited] = params[:inherited] == "true"
    options[:deleted] = params[:deleted] == "true"
    options[:project_id] = params[:project_id].to_i unless params[:project_id].to_i == 0
    options[:user_id] = params[:user_id].to_i unless params[:user_id].to_i == 0
    options[:datetime] = Time.now.strftime "%Y%m%d_%H%M"
    options
  end

  def deploy_filter
    # sanitizes parameters and generates a filter string for use with the Deploy.joins(:stage, :jobs)
    filter = {}

    if start_date = params[:start_date].presence
      start_date = Date.parse(start_date)
    end

    if end_date = params[:end_date].presence
      end_date = Date.parse(end_date)
    end

    if start_date || end_date
      start_date ||= Date.new(1900, 1, 1)
      end_date ||= Date.today
      filter['deploys.created_at'] = (start_date..end_date)
    end

    # We are filtering on a different joins if we enabled DeployGroups.  Deploy groups moves the correct
    # location of the production value to the Environment model instead of the Stage model
    filter_key = (DeployGroup.enabled? ? 'environments.production' : 'stages.production')
    if production = params[:production].presence
      case production
      when 'Yes'  then filter[filter_key] = true
      when 'No'   then filter[filter_key] = false
      else
        raise "Invalid production filter #{production}"
      end
    end

    if status = params[:status].presence
      if ['succeeded', 'failed'].include?(status)
        filter['jobs.status'] = status
      elsif status != 'all'
        raise "Invalid status filter #{status}"
      end
    end

    if project_permalinks = params[:project_permalinks].to_s.split(",").presence
      filter['stages.project_id'] = Project.where(permalink: project_permalinks).pluck(:id)
    elsif project = params[:project]&.to_i
      if project > 0
        filter['stages.project_id'] = project
      elsif project.to_s != params[:project]
        raise "Invalid project id #{params[:project]}"
      end
    end

    if params[:bypassed] == 'true'
      filter['deploys.buddy_id'] = nil
      filter['stages.no_code_deployed'] = false
    end

    filter
  end
end

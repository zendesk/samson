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
      format.json { render json: @csv_exports }
    end
  end

  def new
    @csv_export = CsvExport.new
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
    CsvExportJob.perform_later(csv_export)
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

    if production = params[:production].presence
      case production
      when 'Yes' then filter['stages.production'] = true
      when 'No'  then filter['stages.production'] = false
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

    if project = params[:project].try(:to_i)
      if project > 0
        filter['stages.project_id'] = project
      elsif project.to_s != params[:project]
        raise "Invalid project id #{params[:project]}"
      end
    end

    filter
  end
end

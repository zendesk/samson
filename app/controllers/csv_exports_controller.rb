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
    filters = deploy_filter(params)
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

  def deploy_filter(params)
    # sanitizes parameters and generates a filter string for use with the Deploy.joins(:stage, :jobs)
    filter = {}

    if param = params[:start_date].presence
      start_date = Date.parse(param)
    end

    if param = params[:end_date].presence
      end_date = Date.parse(param)
    end

    if start_date || end_date
      start_date ||= Date.new
      end_date ||= Date.today
      filter['deploys.created_at'] = (start_date..end_date)
    end

    if param = params[:production].presence
      case param
        when 'Yes' then filter['stages.production'] = true
        when 'No'  then filter['stages.production'] = false
        when "Any" then #ignore
        else
          raise "Invalid production filter #{param}"
      end
    end

    if param = params[:status].presence
      if ['succeeded', 'failed'].include?(param)
        filter['jobs.status'] = param
      elsif param != "all"
        raise "Invalid status filter #{param}"
      end
    end

    if param = params[:project].presence
      if param.to_i > 0
        filter['stages.project_id'] = param.to_i
      elsif param != "0"
        raise "Invalid project id #{param}"
      end
    end

    filter
  end
end

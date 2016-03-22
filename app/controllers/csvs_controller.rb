class CsvsController < ApplicationController

  def index
    respond_to do |format|
      @csv_exports = CsvExport.where(user_id: current_user.id)
      format.html
      format.json { render json: @csv_exports }
    end
  end
  
  def show
    respond_to do |format|
      @csv_export = CsvExport.find(params[:id])
      format.html
      format.json { render json: @csv_export }
      format.csv { download(params) }
    end
  end

  def create
    csv_export = CsvExport.create!(user: current_user, content: params[:content], filters: params.to_json)
    csv_export.pending!
    CsvExportJob.perform_later(csv_export.id)
    redirect_to action: "show", id: csv_export.id
  end

  private

  def download(params)
    csv_export = CsvExport.find(params[:id])
    check_file(csv_export)
    if csv_export.status? :ready
      send_file csv_export.full_filename, type: :csv, filename: csv_export.filename
      csv_export.downloaded!
      Rails.logger.info("#{current_user.name_and_email} just downloaded #{csv_export.filename})")
    else
      redirect_to action: 'show', id: params[:id]
    end
  end

  def check_file(csv_export)
    if csv_export.status? :ready
      csv_export.deleted! unless File.exist?(csv_export.full_filename)
    end
  end

  rescue_from ActiveRecord::RecordNotFound do |exception|
    respond_to do |format|
      format.json { render json: {status: "not found"}.to_json, status: :not_found }
      format.csv { render body: "not found", status: :not_found }
      format.all { render file: "#{Rails.public_path}/404.html", status: :not_found }
    end
  end
end

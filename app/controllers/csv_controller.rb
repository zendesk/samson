class CsvController < ApplicationController

  def index
    respond_to do |format|
      @csv_exports = CsvExport.where(user_id: current_user.id)
      format.html
      format.json do
        if @csv_exports.any?
          render json: @csv_exports
        else
          render json: {status: "not-found"}.to_json, :status => 404
        end
      end
    end
  end
  
  def status
    respond_to do |format|
      @csv_export = CsvExport.find_by_id(params[:id])
      format.html
      format.json do
        if @csv_export.nil?
          render json: {status: "not-found"}.to_json, :status => 404
        else
          render json: @csv_export
        end
      end
    end
  end

  def download
    if CsvExport.where(id: params[:id]).any?
      csv_export = CsvExport.find(params[:id])
      sent = false
      if csv_export.finished? or csv_export.downloaded?
        filename = "#{Rails.root}/export/#{csv_export.id}"
        if File.exist?(filename)
          send_file filename, type: :csv, filename: csv_export.filename
          csv_export.downloaded!
          sent = true
          Rails.logger.info("#{current_user.name_and_email} just downloaded #{csv_export.filename})")
        else
          csv_export.deleted!
        end
      end
    end
    redirect_to action: "status", id: params[:id] unless sent
  end

  def create
    csv_export = CsvExport.create(user: current_user, content: params[:content])
    csv_export.pending!
    
    CsvExportJob.perform_later(csv_export.id)
    redirect_to action: "status", id: csv_export.id
  end
end

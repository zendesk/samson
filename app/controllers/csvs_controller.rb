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
      @csv_export = CsvExport.find_by_id(params[:id])
      format.html { not_found if @csv_export.nil? }
      format.json do
        if @csv_export.nil?
          not_found_json
        else
          render json: @csv_export
        end
      end
      format.csv { download(params) }
    end
  end

  def create
    csv_export = CsvExport.create(user: current_user, content: params[:content])
    csv_export.pending!
    CsvExportJob.perform_later(csv_export.id)
    redirect_to action: "show", id: csv_export.id
  end

  private

  def download(params)
    csv_export = CsvExport.find_by_id(params[:id])
    if !csv_export.nil?
      check_file(csv_export)
      if csv_export.ready?
        filename = full_filename(csv_export)
        send_file filename, type: :csv, filename: csv_export.filename
        csv_export.downloaded!
        Rails.logger.info("#{current_user.name_and_email} just downloaded #{csv_export.filename})")
      else
        redirect_to action: 'show', id: params[:id]
      end
    else
      not_found
    end
  end

  def check_file(csv_export)
    if (csv_export.ready?)
      filename = full_filename(csv_export)
      csv_export.deleted! if !File.exist?(filename)
    end
  end

  def not_found_json
    render json: {status: "not-found"}.to_json, :status => 404
  end

  def not_found
    redirect_to({action: 'index'}, flash: { error: "The CSV export does not exist." })
  end

  def full_filename(csv_export)
    "#{Rails.root}/export/#{csv_export.id}"
  end
end

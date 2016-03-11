class CsvExportJob < ActiveJob::Base
  require 'csv'
  
  queue_as :csv_jobs
 
  def perform(csv_export_id)
    ActiveRecord::Base.connection_pool.with_connection do
      csv_export = CsvExport.find(csv_export_id)
      create_export_folder

      export_task(csv_export) unless csv_export.nil?

      cleanup_downloaded
    end
  end
  
  private
  
  def cleanup_downloaded
    # clean up downloaded files older than 12 hours or any jobs stuck for over 1 month
    @csv_exports = CsvExport.where("(status = 'downloaded' AND updated_at <= :end_date) OR updated_at <= :timeout_date",
      {end_date: (Time.now - Rails.application.config.samson.export_job.downloaded_age),
       timeout_date: (Time.now - Rails.application.config.samson.export_job.max_age)})
    if @csv_exports
      @csv_exports.each do |csv_downloaded|
        filename = get_filename(csv_downloaded)
        File.delete(filename) unless !File.exist?(filename)
        csv_downloaded.deleted!
        csv_downloaded.soft_delete!
        Rails.logger.info("Downloaded file #{csv_downloaded.filename} deleted")
      end
    end
  end
  
  def export_task(csv_export)
    begin
      csv_export.filename
      filename = get_filename(csv_export)
      
      if csv_export.content == "deploys"
        csv_export.started!
        deploy_csv_export(filename)
      else
        csv_export.failed!
      end
      
      export_completed_notify(csv_export)
    rescue
      delete_file(get_filename(csv_export))
      csv_export.failed!
      Rails.logger.info("Export #{csv_export.filename} failed");
    end
  end
  
  def export_completed_notify(csv_export)
    if csv_export.started?
      CsvMailer.created_email(csv_export)
      csv_export.finished!
      Rails.logger.info("Export #{csv_export.filename} completed")
    end
  end
  
  def deploy_csv_export(filename)
    @deploys = Deploy.joins(:stage).all()
    CSV.open(filename, 'w+') do |csv|
      csv << ["Deploy Number", "Project Name", "Deploy Sumary", "Deploy Updated", "Deploy Created", "Deployer Name", "Buddy Name", "Production Flag", Deploy.joins(:stage).count.to_s + " Deploys"]
      Deploy.uncached do
        @deploys.find_each do |deploy|
          csv << [deploy.id, deploy.project.name, deploy.summary, deploy.updated_at, deploy.start_time, deploy.job.user.name, deploy.csv_buddy, deploy.stage.production]
        end
      end
    end
  end
  
  def create_export_folder
    Dir.mkdir("#{Rails.root}/export") unless File.exist?("#{Rails.root}/export")
  end
  
  def get_filename(csv_export)
    "#{Rails.root}/export/#{csv_export.id}"
  end
  
  def delete_file(filename)
    File.delete(filename) if File.exist?(filename)
  end
end

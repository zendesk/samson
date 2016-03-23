require 'csv'

class CsvExportJob < ActiveJob::Base
  queue_as :csv_jobs
 
  def perform(csv_export_id)
    ActiveRecord::Base.connection_pool.with_connection do
      csv_export = CsvExport.find(csv_export_id)
      create_export_folder(csv_export)
      export_task(csv_export)
      cleanup_downloaded
    end
  end
  
  private
  
  def cleanup_downloaded
    # clean up downloaded files older than 12 hours or any jobs stuck for over 1 month
    # TODO delete files with no record associations
    end_date = Time.now - Rails.application.config.samson.export_job.downloaded_age
    timeout_date = Time.now - Rails.application.config.samson.export_job.max_age
    @csv_exports = CsvExport.where("(status = 'downloaded' AND updated_at <= :end_date) OR updated_at <= :timeout_date",
      {end_date: end_date, timeout_date: timeout_date})
    @csv_exports.each do |csv_export|
      csv_export.destroy
      Rails.logger.info("Downloaded file #{csv_export.download_name} deleted")
    end
  end
  
  def export_task(csv_export)
    csv_export.status! :started
    deploy_csv_export(csv_export)
    notify_of_creation(csv_export)
  rescue
    csv_export.status! :failed
    Rails.logger.info("Export #{csv_export.download_name} failed")
  end
  
  def notify_of_creation(csv_export)
    CsvMailer.created_email(csv_export).deliver_now if csv_export.email.present?
    csv_export.status! :finished
    Rails.logger.info("Export #{csv_export.download_name} completed")
  end
  
  def deploy_csv_export(csv_export)
    filename = csv_export.path_file
    filter = csv_export.filters

    @deploys = Deploy.joins(:stage, :job).where(filter)
    summary = [ "-", "Deploys", @deploys.count.to_s ]
    filters_applied = [ "-", "Filters", filter.to_json ]

    CSV.open(filename, 'w+') do |csv|
      csv << ["Deploy Number", "Project Name", "Deploy Sumary", "Deploy Commit", "Deploy Status", "Deploy Updated",
        "Deploy Created", "Deployer Name", "Deployer Email", "Buddy Name", "Buddy Email",
        "Production Flag", "Bypass Buddy Check" ]
      Deploy.uncached do
        @deploys.find_each do |deploy|
          csv << [deploy.id, deploy.project.name, deploy.summary, deploy.commit, deploy.job.status, deploy.updated_at,
            deploy.start_time, deploy.job.user.name, deploy.job.user.try(:email), deploy.csv_buddy, deploy.buddy_email,
            deploy.stage.production, deploy.stage.bypass_buddy_check ]
        end
      end
      csv << summary
      csv << filters_applied
    end
  end
  
  def create_export_folder(csv_export)
    Dir.mkdir(File.dirname(csv_export.path_file)) unless File.exist?(File.dirname(csv_export.path_file))
  end
end

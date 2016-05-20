require 'csv'

class CsvExportJob < ActiveJob::Base
  queue_as :csv_jobs

  def perform(csv_export)
    ActiveRecord::Base.connection_pool.with_connection do
      create_export_folder(csv_export)
      generate_csv(csv_export)
      cleanup_downloaded
    end
  end

  private

  def cleanup_downloaded
    CsvExport.old.find_each(&:destroy!)
  end

  def generate_csv(csv_export)
    csv_export.status! :started
    deploy_csv_export(csv_export)
    CsvMailer.created(csv_export).deliver_now if csv_export.email.present?
    csv_export.status! :finished
    Rails.logger.info("Export #{csv_export.download_name} completed")
  rescue Errno::EACCES, IOError, ActiveRecord::ActiveRecordError => e
    csv_export.delete_file
    csv_export.status! :failed
    Rails.logger.error("Export #{csv_export.id} failed with error #{e}")
    Airbrake.notify(e, error_message: "Export #{csv_export.id} failed.")
  end

  def deploy_csv_export(csv_export)
    filename = csv_export.path_file
    filter = csv_export.filters

    @deploys = Deploy.joins(:stage, :job).where(filter)
    summary = ["-", "Generated At", csv_export.updated_at, "Deploys", @deploys.count.to_s]
    filters_applied = ["-", "Filters", filter.to_json]

    CSV.open(filename, 'w+') do |csv|
      csv << [
        "Deploy Number", "Project Name", "Deploy Sumary", "Deploy Commit", "Deploy Status", "Deploy Updated",
        "Deploy Created", "Deployer Name", "Deployer Email", "Buddy Name", "Buddy Email",
        "Production Flag", "No code deployed"
      ]
      @deploys.find_each do |deploy|
        csv << [
          deploy.id, deploy.project.name, deploy.summary, deploy.commit, deploy.job.status, deploy.updated_at,
          deploy.start_time, deploy.job.user.name, deploy.job.user.try(:email), deploy.buddy_name, deploy.buddy_email,
          deploy.stage.production, deploy.stage.no_code_deployed
        ]
      end
      csv << summary
      csv << filters_applied
    end
  end

  def create_export_folder(csv_export)
    FileUtils.mkdir_p(File.dirname(csv_export.path_file))
  end
end

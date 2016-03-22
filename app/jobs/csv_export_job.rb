require 'csv'

class CsvExportJob < ActiveJob::Base
  queue_as :csv_jobs
 
  def perform(csv_export_id)
    ActiveRecord::Base.connection_pool.with_connection do
      csv_export = CsvExport.find(csv_export_id)
      create_export_folder
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
    if @csv_exports
      @csv_exports.each do |csv_downloaded|
        filename = csv_downloaded.full_filename
        File.delete(filename) unless !File.exist?(filename)
        csv_downloaded.delete
        Rails.logger.info("Downloaded file #{csv_downloaded.filename} deleted")
      end
    end
  end
  
  def export_task(csv_export)
    if csv_export.content == "deploys"
      csv_export.started!
      deploy_csv_export(csv_export)
    else
      csv_export.failed!
    end

    notify_of_creation(csv_export)
  rescue
    #delete_file(csv_export.full_filename)
    csv_export.failed!
    Rails.logger.info("Export #{csv_export.filename} failed")
  end
  
  def notify_of_creation(csv_export)
    if csv_export.status? :started
      CsvMailer.created_email(csv_export).deliver_now unless (csv_export.email.nil? || csv_export.email.empty?)
      csv_export.finished!
      Rails.logger.info("Export #{csv_export.filename} completed")
    end
  end
  
  def deploy_csv_export(csv_export)
    filename = csv_export.full_filename
    filter = deploy_filter(csv_export)

    if filter == {}
      @deploys = Deploy.joins(:stage, :job).all
    else
      @deploys = Deploy.joins(:stage, :job).where(filter)
    end
    summary = [ "-", "Deploys", @deploys.count.to_s ]
    filters_applied = [ "-", "Filters", filter.to_json ]

    CSV.open(filename, 'w+') do |csv|
      csv << ["Deploy Number", "Project Name", "Deploy Sumary", "Deploy Commit", "Deploy Status", "Deploy Updated",
        "Deploy Created", "Deployer Name" "Deployer Email", "Buddy Name", "Buddy Email",
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
  
  def create_export_folder
    Dir.mkdir("#{Rails.root}/export") unless File.exist?("#{Rails.root}/export")
  end

  def delete_file(filename)
    File.delete(filename) if File.exist?(filename)
  end

  def deploy_filter(csv_export)
    # sanitizes parameters and generates a filter string for use with the Deploy.joins(:stage, :jobs)
    params = csv_export.filters
    filter = {}

    start_date = Date.new
    end_date = Date.today
    orig_dates = [ start_date, end_date]

    if params.key?(:start_date)
      begin
        start_date = date_from_params params[:start_date]
      rescue
        Rails.logger.error "Invalid start date for report, using 0."
      end
    end

    if params.key?(:end_date)
      begin
        end_date = date_from_params params[:end_date]
      rescue
        Rails.logger.error "Invalid end date for report, applying no end date filter to report."
      end
    end

    unless start_date == orig_dates[0] && end_date == orig_dates[1]
      filter['deploys.created_at'] = (start_date..end_date)
    end

    if params.key?(:production)
      if params[:production] == 'Yes'
        filter['stages.production'] = true
      elsif params[:production] == 'No'
        filter['stages.production'] = false
      end
    end

    if params.key?(:status)
      status = []
      params[:status].each do |s|
        if ['succeeded', 'running', 'failed', 'errored', 'cancelling', 'cancelled'].include?(s)
          status << s
        end
        if status.length > 0 and status.length < 6
          filter['jobs.status'] = status
        end
      end
    end

    if params.key?(:project)
      begin
        if params[:project].to_i != 0
          filter['stages.project_id'] = params[:project].to_i
        end
      rescue
        Rails.logger.error "Invalid project value for report, applying no project filter to report."
      end
    end

    filter
  end

  def date_from_params(date)
    Date.civil(date[:year].to_i, date[:month].to_i, date[:day].to_i)
  end
end

# frozen_string_literal: true
require 'csv'

class CsvExportJob
  def initialize(csv_export)
    @csv_export = csv_export
  end

  # used to identify in JobQueue
  def id
    "csv-export-#{@csv_export.id}"
  end

  def perform
    ActiveRecord::Base.connection_pool.with_connection do
      create_export_folder(@csv_export)
      generate_csv(@csv_export)
      cleanup_downloaded
    end
  end

  private

  def cleanup_downloaded
    CsvExport.old.find_each(&:destroy!)
  end

  def generate_csv(csv_export)
    csv_export.status! :started
    remove_deleted_scope_and_create_report(csv_export)
    CsvMailer.created(csv_export).deliver_now if csv_export.email.present?
    csv_export.status! :finished
    Rails.logger.info("Export #{csv_export.download_name} completed")
  rescue Errno::EACCES, IOError, ActiveRecord::ActiveRecordError => e
    csv_export.delete_file
    csv_export.status! :failed
    Rails.logger.error("Export #{csv_export.id} failed with error #{e}")
    Samson::ErrorNotifier.notify(e, error_message: "Export #{csv_export.id} failed.")
  end

  # Helper method to removes the default soft_deletion scope for these models for the report
  def remove_deleted_scope_and_create_report(csv_export)
    with_deleted { deploy_csv_export(csv_export) }
  end

  def deploy_csv_export(csv_export)
    filename = csv_export.path_file
    filter = csv_export.filters

    deploys = filter_deploys(filter)
    summary = ["-", "Generated At", csv_export.updated_at, "Deploys", deploys.count.to_s]
    filters_applied = ["-", "Filters", filter.to_json]

    CSV.open(filename, 'w+') do |csv|
      csv << Deploy.csv_header
      deploys.find_each do |deploy|
        csv << deploy.csv_line
      end
      csv << summary
      csv << filters_applied
    end
  end

  def filter_deploys(filter)
    if filter.key?('environments.production')
      production_value = filter.delete('environments.production')
      # To match logic of stages.production? True when any deploy_group environment is true or
      # deploy_groups environment is empty and stages is true
      production_query = if production_value
        "(StageProd.production = ? OR (StageProd.production IS NULL AND stages.production = ?))"
      else
        "(NOT StageProd.production = ? OR (StageProd.production IS NULL AND NOT stages.production = ?))"
      end

      # This subquery extracts the distinct pairs of stage.id to environment.production for the join below as StageProd
      stage_prod_subquery = "(SELECT DISTINCT deploy_groups_stages.stage_id, environments.production "\
      "FROM deploy_groups_stages " \
      "INNER JOIN deploy_groups ON deploy_groups.id = deploy_groups_stages.deploy_group_id " \
      "INNER JOIN environments ON environments.id = deploy_groups.environment_id) StageProd"

      # The query could result in duplicate entries when a stage has a production and non-production deploy group
      # so it is important this is run only if environments.production was set
      Deploy.includes(:buddy, job: :user, stage: :project).joins(:job, :stage).
        joins("LEFT JOIN #{stage_prod_subquery} ON StageProd.stage_id = stages.id").
        where(filter).where(production_query, true, true)
    else
      Deploy.includes(:buddy, job: :user, stage: :project).joins(:job, :stage).where(filter)
    end
  end

  def create_export_folder(csv_export)
    FileUtils.mkdir_p(File.dirname(csv_export.path_file))
  end

  def with_deleted(&block)
    Deploy.with_deleted do
      Stage.with_deleted do
        Project.with_deleted do
          DeployGroup.with_deleted do
            Environment.with_deleted &block
          end
        end
      end
    end
  end
end

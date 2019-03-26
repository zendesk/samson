# frozen_string_literal: true
require 'csv'

class DeployMetricsCsvPresenter
  class << self
    def to_csv
      Enumerator.new do |yielder|
        yielder << CSV.generate_line(csv_header)

        production_stages = Stage.select(&:production?)
        deploys = Deploy.succeeded.where(stage: production_stages).includes(:job, stage: :project)
        deploys.each do |deploy|
          yielder << CSV.generate_line(csv_line(deploy))
        end
      end
    end

    private

    def csv_header
      [
        "Deploy Number",
        "Project Name",
        "Deploy Commit",
        "Deploy Status",
        "Stage Name",
        "PR - Production Cycle Time",
        "Staging - Production Cycle Time"
      ]
    end

    def csv_line(deploy)
      [
        deploy.id,
        deploy.stage.project.permalink,
        deploy.commit,
        deploy.job.status,
        deploy.stage.name,
        deploy.cycle_time[:pr_production],
        deploy.cycle_time[:staging_production]
      ]
    end
  end
end

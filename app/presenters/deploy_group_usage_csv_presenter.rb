# frozen_string_literal: true
require 'csv'

class DeployGroupUsageCsvPresenter
  class << self
    def to_csv
      CSV.generate do |csv|
        csv << csv_header
        Project.all.each do |project|
          if project.stages.empty?
            csv << csv_line(project)
          else
            project.stages.each do |stage|
              stage.deploy_groups.each do |deploy_group|
                csv << csv_line(project, stage, deploy_group)
              end
            end
          end
        end
      end
    end

    private

    def csv_header
      [
        "project_name",
        "stage_name",
        "deploy_group_name",
        "deploy_group_environment_id",
        "deploy_group_environment_name",
        "deploy_group_env_value",
        "deploy_group_permalink"
      ]
    end

    def csv_line(project, stage = nil, deploy_group = nil)
      result = [project.name]
      if stage && deploy_group
        result.concat [
          stage.name,
          deploy_group.name,
          deploy_group.environment_id,
          deploy_group.environment.name,
          deploy_group.env_value,
          deploy_group.permalink
        ]
      end
      result
    end
  end
end

# frozen_string_literal: true
require 'csv'

class DeployGroupUsageCsvPresenter
  def self.to_csv
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

  def self.csv_header
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

  def self.csv_line(project, stage = nil, deploy_group = nil)
    result = []
    if stage && deploy_group
      result << stage.name
      result << deploy_group.name
      result << deploy_group.environment_id
      result << deploy_group.environment.name
      result << deploy_group.env_value
      result << deploy_group.permalink
    end
    result.unshift(project.name)
  end
end

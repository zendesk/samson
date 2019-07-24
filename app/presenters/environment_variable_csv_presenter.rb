# frozen_string_literal: true
require 'csv'

class EnvironmentVariableCsvPresenter
  class << self
    def to_csv
      CSV.generate do |csv|
        csv << csv_header
        EnvironmentVariableGroup.all.each do |group|
          group.environment_variables.each do |env_var|
            csv << [env_var.name, env_var.value, group.name]
          end
        end

        Project.all.each do |project|
          project.environment_variables.each do |env_var|
            csv << [env_var.name, env_var.value, project.name]
          end
        end
      end
    end

    private

    def csv_header
      [
        "name",
        "value",
        "parent"
      ]
    end
  end
end

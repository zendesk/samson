# frozen_string_literal: true
class DeleteAbandomedEnvVars < ActiveRecord::Migration[5.0]
  class EnvironmentVariable < ActiveRecord::Base
  end

  class EnvironmentVariableGroup < ActiveRecord::Base
  end

  class Project < ActiveRecord::Base
  end

  class DeployGroup < ActiveRecord::Base
  end

  class Environment < ActiveRecord::Base
  end

  class ProjectEnvironmentVariableGroup < ActiveRecord::Base
  end

  def up
    # cleanup EnvironmentVariable by parent
    [Project, EnvironmentVariableGroup].each do |klass|
      existing = klass.pluck(:id)
      deleted = EnvironmentVariable.where(parent_type: klass.name).where('parent_id NOT IN(?)', existing).delete_all
      puts "DELETED #{deleted} #{klass.name} EnvironmentVariables by parent"
    end

    # cleanup EnvironmentVariable by scope
    [DeployGroup, Environment].each do |klass|
      existing = klass.pluck(:id)
      deleted = EnvironmentVariable.where(scope_type: klass.name).where('scope_id NOT IN(?)', existing).delete_all
      puts "DELETED #{deleted} #{klass.name} EnvironmentVariables by scope"
    end

    # cleanup ProjectEnvironmentVariableGroup by project and group
    project_ids = Project.pluck(:id)
    deleted = ProjectEnvironmentVariableGroup.where('project_id NOT IN(?)', project_ids).delete_all
    puts "DELETED #{deleted} ProjectEnvironmentVariableGroup by project"

    group_ids = EnvironmentVariableGroup.pluck(:id)
    deleted = ProjectEnvironmentVariableGroup.where('environment_variable_group_id NOT IN(?)', group_ids).delete_all
    puts "DELETED #{deleted} ProjectEnvironmentVariableGroup by environment_variable_group"
  end

  def down
  end
end

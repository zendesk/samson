# frozen_string_literal: true
# rubocop:disable Layout/LineLength
class MoveEnvToProject < ActiveRecord::Migration[4.2]
  def change
    rename_table :stage_environment_variable_groups, :project_environment_variable_groups
    rename_column :project_environment_variable_groups, :stage_id, :project_id
    rename_index :project_environment_variable_groups, "stage_environment_variable_groups_unique_group_id", "project_environment_variable_groups_unique_group_id"
    rename_index :project_environment_variable_groups, "stage_environment_variable_groups_group_id", "project_environment_variable_groups_group_id"

    ProjectEnvironmentVariableGroup.find_each do |peg|
      if stage = Stage.find_by_id(peg.project_id)
        peg.update_attribute(:project_id, stage.project_id)
      else
        peg.destroy
      end
    end

    EnvironmentVariable.where(parent_type: "Stage").each do |ev|
      if stage = ev.parent
        ev.update_attribute(:parent, stage.project)
      end
    end
  end
end
# rubocop:enable Layout/LineLength

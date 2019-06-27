# frozen_string_literal: true

class AddPrerequisiteStageIdsToStages < ActiveRecord::Migration[5.2]
  def change
    add_column :stages, :prerequisite_stage_ids, :string
  end
end

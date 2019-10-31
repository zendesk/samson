# frozen_string_literal: true
class AddPipelineToNextStagesToDeploys < ActiveRecord::Migration[5.2]
  def change
    add_column :stages, :pipeline_to_next_stages_allowed, :boolean, default: false, null: false
    add_column :deploys, :pipeline_to_next_stages, :boolean, default: false, null: false
  end
end

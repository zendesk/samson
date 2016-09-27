# frozen_string_literal: true
class SaveSourceTemplateToCloneStage < ActiveRecord::Migration[5.0]
  def change
    add_column :stages, :template_stage_id, :integer
    add_index :stages, :template_stage_id
  end
end

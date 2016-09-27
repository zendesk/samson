class SaveSourceTemplateToCloneStage < ActiveRecord::Migration[5.0]
  def change
    add_column :stages, :template_stage_id, :integer
  end
end

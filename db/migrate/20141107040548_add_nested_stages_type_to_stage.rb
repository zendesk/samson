class AddNestedStagesTypeToStage < ActiveRecord::Migration
  def change
    add_column :stages, :nested_stages_type, :string
  end
end

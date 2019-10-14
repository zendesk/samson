class AddSetupHookToStage < ActiveRecord::Migration[5.2]
  def change
    add_column :stages, :external_setup_hook_id, :integer
  end
end

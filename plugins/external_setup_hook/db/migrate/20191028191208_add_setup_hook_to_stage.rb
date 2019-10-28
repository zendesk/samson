class AddSetupHookToStage < ActiveRecord::Migration[5.2]
  def change
    create_table :external_setup_hook_stages do |t|
      t.belongs_to :external_setup_hook, null: false, index: true
      t.belongs_to :stage, null: false, index: true
    end
  end
end

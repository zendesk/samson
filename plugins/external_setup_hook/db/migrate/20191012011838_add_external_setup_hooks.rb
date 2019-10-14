class AddExternalSetupHooks < ActiveRecord::Migration[5.2]
  def up
    create_table :external_setup_hooks do |t|
      t.string :name, null: false
      t.string :description
      t.string :endpoint, null: false
      t.string :auth_type, default: "token", null: false
      t.string :auth_token, null: false
      # t.integer :parent_id, null: false
      # t.string :parent_type, null: false
      # t.integer :deploy_group_id
    end
    # add_index :environment_variable_groups, :name, unique: true, length: 191

    # create_table :stage_environment_variable_groups do |t|
    #   t.integer :stage_id, :environment_variable_group_id, null: false
    # end

    # add_index :stage_environment_variable_groups, [:stage_id, :environment_variable_group_id], unique: true, name: "stage_environment_variable_groups_unique_group_id"
    # add_index :stage_environment_variable_groups, :environment_variable_group_id, name: "stage_environment_variable_groups_group_id"
  end

  def down
    drop_table :external_setup_hooks
  end
end

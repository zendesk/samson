class CreateUserProjectRoles < ActiveRecord::Migration
  create_table :user_project_roles do |t|
    t.belongs_to :project, null: false, index: true
    t.belongs_to :user,    null: false, index: true
    t.integer :role_id,    null: false
    t.timestamps           null: false
  end
end

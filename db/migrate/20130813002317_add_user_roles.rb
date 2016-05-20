class AddUserRoles < ActiveRecord::Migration
  def change
    change_table :users do |t|
      t.integer :role_id, null: false, default: 0
    end
  end
end

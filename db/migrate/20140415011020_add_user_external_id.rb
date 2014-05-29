class AddUserExternalId < ActiveRecord::Migration
  def change
    add_column :users, :external_id, :string
    add_index :users, :external_id, unique: true
  end
end

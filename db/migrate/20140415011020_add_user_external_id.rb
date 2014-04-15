class AddUserExternalId < ActiveRecord::Migration
  def change
    add_column :users, :external_id, :integer
  end
end

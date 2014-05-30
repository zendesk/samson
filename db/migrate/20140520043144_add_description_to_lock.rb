class AddDescriptionToLock < ActiveRecord::Migration
  def change
    add_column :locks, :description, :string
  end
end

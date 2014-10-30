class AddAncestryToDeploys < ActiveRecord::Migration
  def change
    add_column :deploys, :ancestry, :string
    add_index :deploys, :ancestry
  end
end

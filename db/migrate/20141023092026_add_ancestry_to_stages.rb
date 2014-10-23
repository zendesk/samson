class AddAncestryToStages < ActiveRecord::Migration
  def change
    add_column :stages, :ancestry, :string
    add_index :stages, :ancestry
  end
end

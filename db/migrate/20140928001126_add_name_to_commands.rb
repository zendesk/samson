class AddNameToCommands < ActiveRecord::Migration
  def change
    add_column :commands, :name, :string
  end
end

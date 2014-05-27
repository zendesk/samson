class RemoveCommandFromStage < ActiveRecord::Migration
  def change
    remove_column :stages, :command
  end
end

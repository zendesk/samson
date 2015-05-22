class AddCommandTypeToStages < ActiveRecord::Migration
  def change
    change_table :stages do |t|
      t.string :command_type
    end
  end
end

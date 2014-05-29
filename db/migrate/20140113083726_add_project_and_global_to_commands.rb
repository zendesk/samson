class AddProjectAndGlobalToCommands < ActiveRecord::Migration
  def change
    change_table :commands do |t|
      t.remove :user_id
      t.belongs_to :project
    end
  end
end

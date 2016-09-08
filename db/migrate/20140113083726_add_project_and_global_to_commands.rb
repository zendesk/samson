# frozen_string_literal: true
class AddProjectAndGlobalToCommands < ActiveRecord::Migration[4.2]
  def change
    change_table :commands do |t|
      t.remove :user_id
      t.belongs_to :project
    end
  end
end

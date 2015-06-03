class CreateCommands < ActiveRecord::Migration
  def change
    create_table :commands do |t|
      t.text :command, limit: 10.megabytes / 4
      t.belongs_to :user
      t.timestamps
    end
  end
end

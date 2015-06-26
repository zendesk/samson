class AddNameToCommand < ActiveRecord::Migration
  def change
    change_table :commands do |t|
      t.string :name, before: :command
    end
  end
end

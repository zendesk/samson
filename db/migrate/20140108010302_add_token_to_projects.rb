class AddTokenToProjects < ActiveRecord::Migration
  def change
    change_table :projects do |t|
      t.string :token
      t.index :token
    end
  end
end

class AddTokenToProjects < ActiveRecord::Migration
  def change
    change_table :projects do |t|
      t.string :token
      t.index :token, length: 191
    end
  end
end

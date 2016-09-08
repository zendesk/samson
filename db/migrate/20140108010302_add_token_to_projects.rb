# frozen_string_literal: true
class AddTokenToProjects < ActiveRecord::Migration[4.2]
  def change
    change_table :projects do |t|
      t.string :token
      t.index :token, length: 191
    end
  end
end

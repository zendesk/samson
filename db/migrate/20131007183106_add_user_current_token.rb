# frozen_string_literal: true
class AddUserCurrentToken < ActiveRecord::Migration[4.2]
  def change
    change_table :users do |t|
      t.string :current_token
    end
  end
end

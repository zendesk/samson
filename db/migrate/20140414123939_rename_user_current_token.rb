# frozen_string_literal: true
class RenameUserCurrentToken < ActiveRecord::Migration[4.2]
  def change
    change_table :users do |t|
      t.rename :current_token, :token
    end
  end
end

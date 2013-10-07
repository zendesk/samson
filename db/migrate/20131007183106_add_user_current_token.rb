class AddUserCurrentToken < ActiveRecord::Migration
  def change
    change_table :users do |t|
      t.string :current_token
    end
  end
end

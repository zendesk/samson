class RenameUserCurrentToken < ActiveRecord::Migration
  def change
    change_table :users do |t|
      t.rename :current_token, :token
    end
  end
end

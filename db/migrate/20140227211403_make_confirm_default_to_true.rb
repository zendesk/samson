class MakeConfirmDefaultToTrue < ActiveRecord::Migration
  def up
    change_column :stages, :confirm, :boolean, default: true
  end

  def down
    change_column :stages, :confirm, :boolean, default: nil
  end
end

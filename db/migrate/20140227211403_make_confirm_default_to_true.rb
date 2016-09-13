# frozen_string_literal: true
class MakeConfirmDefaultToTrue < ActiveRecord::Migration[4.2]
  def up
    change_column :stages, :confirm, :boolean, default: true
  end

  def down
    change_column :stages, :confirm, :boolean, default: nil
  end
end

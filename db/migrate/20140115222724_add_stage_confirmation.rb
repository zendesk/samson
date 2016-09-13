# frozen_string_literal: true
class AddStageConfirmation < ActiveRecord::Migration[4.2]
  def change
    change_table :stages do |t|
      t.boolean :confirm
    end
  end
end

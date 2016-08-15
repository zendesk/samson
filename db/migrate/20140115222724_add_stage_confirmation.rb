# frozen_string_literal: true
class AddStageConfirmation < ActiveRecord::Migration
  def change
    change_table :stages do |t|
      t.boolean :confirm
    end
  end
end

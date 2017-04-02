# frozen_string_literal: true
class AddMacroToStages < ActiveRecord::Migration[5.0]
  def change
    add_column :stages, :no_reference_selection, :boolean, default: false, null: false
  end
end

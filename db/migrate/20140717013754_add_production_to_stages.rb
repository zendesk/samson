# frozen_string_literal: true
class AddProductionToStages < ActiveRecord::Migration[4.2]
  def change
    add_column :stages, :production, :boolean, default: false
  end
end

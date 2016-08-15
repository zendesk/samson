# frozen_string_literal: true
class AddProductionToStages < ActiveRecord::Migration
  def change
    add_column :stages, :production, :boolean, default: false
  end
end

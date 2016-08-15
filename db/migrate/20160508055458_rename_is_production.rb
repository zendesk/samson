# frozen_string_literal: true
class RenameIsProduction < ActiveRecord::Migration
  def change
    rename_column :environments, :is_production, :production
  end
end

# frozen_string_literal: true
class RenameIsProduction < ActiveRecord::Migration[4.2]
  def change
    rename_column :environments, :is_production, :production
  end
end

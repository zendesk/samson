# frozen_string_literal: true
class ReallyAddKubernetesToStaging < ActiveRecord::Migration[4.2]
  def change
    add_column :stages, :kubernetes, :boolean, default: false, null: false
  end
end

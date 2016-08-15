# frozen_string_literal: true
class ReallyAddKubernetesToStaging < ActiveRecord::Migration
  def change
    add_column :stages, :kubernetes, :boolean, default: false, null: false
  end
end

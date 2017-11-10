# frozen_string_literal: true
class AddBuildWithGcbToProject < ActiveRecord::Migration[5.1]
  def change
    add_column :projects, :build_with_gcb, :boolean, default: false, null: false
  end
end

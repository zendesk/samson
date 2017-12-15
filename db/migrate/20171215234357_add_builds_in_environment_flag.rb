# frozen_string_literal: true
class AddBuildsInEnvironmentFlag < ActiveRecord::Migration[5.1]
  def change
    add_column :stages, :builds_in_environment, :boolean, default: false, null: false
  end
end

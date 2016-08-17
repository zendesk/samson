# frozen_string_literal: true
class AddTemplateToStages < ActiveRecord::Migration
  def change
    add_column :stages, :template, :boolean, null: false, default: false
  end
end

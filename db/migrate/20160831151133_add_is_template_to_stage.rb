# frozen_string_literal: true
class AddIsTemplateToStage < ActiveRecord::Migration[4.2]
  def change
    add_column :stages, :is_template, :boolean, default: false, null: false
  end
end

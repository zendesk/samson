# frozen_string_literal: true
class AddDatadogTagToStages < ActiveRecord::Migration[4.2]
  def change
    change_table :stages do |t|
      t.string :datadog_tags
    end
  end
end

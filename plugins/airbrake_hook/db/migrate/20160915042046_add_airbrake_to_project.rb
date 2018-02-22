# frozen_string_literal: true
class AddAirbrakeToProject < ActiveRecord::Migration[5.0]
  def change
    add_column :stages, :notify_airbrake, :boolean, default: false, null: false
  end
end

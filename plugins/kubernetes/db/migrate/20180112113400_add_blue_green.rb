# frozen_string_literal: true
class AddBlueGreen < ActiveRecord::Migration[5.1]
  def change
    add_column :kubernetes_roles, :blue_green, :boolean, default: false, null: false
    add_column :kubernetes_releases, :blue_green_color, :string
  end
end

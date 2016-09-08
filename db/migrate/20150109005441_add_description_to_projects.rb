# frozen_string_literal: true
class AddDescriptionToProjects < ActiveRecord::Migration[4.2]
  def change
    add_column :projects, :description, :text, limit: 65535
    add_column :projects, :owner, :string, limit: 255
  end
end

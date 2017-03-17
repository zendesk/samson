# frozen_string_literal: true
class AddDashboardToProjects < ActiveRecord::Migration[5.0]
  def change
    add_column :projects, :dashboard, :text
  end
end

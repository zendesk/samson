# frozen_string_literal: true
class AddJenkinsStatusChecker < ActiveRecord::Migration[5.1]
  def change
    add_column :projects, :jenkins_status_checker, :boolean, default: false, null: false
  end
end

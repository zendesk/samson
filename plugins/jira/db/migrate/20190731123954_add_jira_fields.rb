# frozen_string_literal: true
class AddJiraFields < ActiveRecord::Migration[5.2]
  def change
    add_column :projects, :jira_issue_prefix, :string
    add_column :stages, :jira_transition_id, :string
  end
end

# frozen_string_literal: true
class Prevent3StateBooleans < ActiveRecord::Migration
  def change
    [:update_github_pull_requests, :comment_on_zendesk_tickets, :use_github_deployment_api].each do |column|
      change_column_default :stages, column, false
      change_column_null :stages, column, false
    end
  end
end

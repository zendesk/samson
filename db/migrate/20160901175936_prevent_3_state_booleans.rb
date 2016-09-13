# frozen_string_literal: true
class Prevent3StateBooleans < ActiveRecord::Migration[4.2]
  class Stage < ActiveRecord::Base
  end

  COLUMNS = [:update_github_pull_requests, :comment_on_zendesk_tickets, :use_github_deployment_api].freeze

  def up
    COLUMNS.each do |column|
      Stage.where(column => nil).update_all(column => false)
      change_column_default :stages, column, false
      change_column_null :stages, column, false
    end
  end

  def down
    COLUMNS.each do |column|
      change_column_default :stages, column, nil
      change_column_null :stages, column, true
    end
  end
end

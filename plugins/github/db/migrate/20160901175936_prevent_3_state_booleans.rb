# frozen_string_literal: true
# same as plugins/zendesk/db/migrate/20160901175937_prevent_3_state_booleans2.rb
class Prevent3StateBooleans < ActiveRecord::Migration[4.2]
  class Stage < ActiveRecord::Base
  end

  COLUMNS = [:update_github_pull_requests, :use_github_deployment_api].freeze

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

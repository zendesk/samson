# frozen_string_literal: true
# same as db/migrate/20160901175936_prevent_3_state_booleans.rb
class Prevent3StateBooleans2 < ActiveRecord::Migration[4.2]
  class Stage < ActiveRecord::Base
  end

  COLUMNS = [:comment_on_zendesk_tickets].freeze

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

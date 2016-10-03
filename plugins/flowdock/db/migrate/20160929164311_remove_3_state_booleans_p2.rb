# frozen_string_literal: true
class Remove3StateBooleansP2 < ActiveRecord::Migration[5.0]
  def change
    change_column_null :flowdock_flows, :enabled, false, false
  end
end

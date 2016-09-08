# frozen_string_literal: true
class AddFlowdockCheckboxToFlowdockFlows < ActiveRecord::Migration[4.2]
  def change
    add_column :flowdock_flows, :enabled, :boolean, default: true
  end
end

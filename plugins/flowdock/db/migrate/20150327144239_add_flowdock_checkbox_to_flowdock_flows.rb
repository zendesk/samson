class AddFlowdockCheckboxToFlowdockFlows < ActiveRecord::Migration
  def change
    add_column :flowdock_flows, :notifications, :boolean, default: false
  end
end

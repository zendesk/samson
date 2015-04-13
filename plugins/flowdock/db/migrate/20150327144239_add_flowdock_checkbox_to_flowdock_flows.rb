class AddFlowdockCheckboxToFlowdockFlows < ActiveRecord::Migration
  def change
    add_column :flowdock_flows, :enabled, :boolean, default: false
  end
end

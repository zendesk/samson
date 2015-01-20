class AddFlowdockCheckboxToFlowdockFlows < ActiveRecord::Migration
  def change
    add_column :flowdock_flows, :enable_notifications, :boolean, default: false
  end
end

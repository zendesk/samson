# frozen_string_literal: true
class RemoveEnabledFlag < ActiveRecord::Migration[5.0]
  class FlowdockFlow < ActiveRecord::Base
  end

  def up
    FlowdockFlow.where(enabled: false).each do |flow|
      puts "Deleting flow from stage #{flow.stage_id}: #{flow.name} #{flow.token}"
      flow.destroy
    end
    remove_column :flowdock_flows, :enabled
  end

  def down
    add_column :flowdock_flows, :enabled, default: true, null: false
  end
end

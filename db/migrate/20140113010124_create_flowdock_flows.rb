class CreateFlowdockFlows < ActiveRecord::Migration
  def change
    create_table :flowdock_flows do |t|
      t.string :name, null: false
      t.string :token, null: false
      t.integer :stage_id, null: false

      t.timestamps
    end
  end
end

class AddServerLogs < ActiveRecord::Migration
  def change
    add_column :stages, :wait_for_server_logs, :boolean, default: false
  end
end

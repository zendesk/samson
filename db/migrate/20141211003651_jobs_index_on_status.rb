class JobsIndexOnStatus < ActiveRecord::Migration
  def change
    add_index :jobs, :status, length: 191
  end
end
